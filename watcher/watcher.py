"""
File watcher — monitors WATCH_DIR for .txt log files.
Ingests new/modified files via the FastAPI ingestion endpoint.
Tracks processed line count per file to handle appended logs.
"""
import json
import logging
import os
import time
from pathlib import Path

import requests
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

API_URL     = os.getenv("API_URL",     "http://localhost:8000")
WATCH_DIR   = os.getenv("WATCH_DIR",   "/watch")
STATE_FILE  = os.getenv("STATE_FILE",  "/tmp/watcher_state.json")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("watcher")


# ── State helpers ─────────────────────────────────────────────────────────────

def load_state() -> dict:
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# ── Ingestion ─────────────────────────────────────────────────────────────────

def ingest_file(path: str, state: dict) -> dict:
    """Send only new lines (since last run) to the API."""
    known      = state.get(path, {})
    prev_lines = known.get("lines_processed", 0)

    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            all_lines = f.readlines()
    except OSError as e:
        log.error("Read failed %s: %s", path, e)
        return state

    new_lines = all_lines[prev_lines:]
    if not new_lines:
        return state

    filename = os.path.basename(path)
    content  = "".join(new_lines)

    try:
        resp = requests.post(
            f"{API_URL}/api/logs/upload",
            files={"file": (filename, content.encode(), "text/plain")},
            timeout=30,
        )
        if resp.ok:
            r = resp.json()
            log.info(
                "%s  +%d líneas  →  upsert:%d  apps_nuevas:%d  omitidas:%d",
                filename, len(new_lines), r["upserted"], r["new_apps"], r["skipped"],
            )
            state[path] = {
                "lines_processed": len(all_lines),
                "mtime": os.path.getmtime(path),
                "last_ingest": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        else:
            log.error("API %s → %d: %s", filename, resp.status_code, resp.text[:300])
    except requests.RequestException as e:
        log.error("Request error: %s", e)

    return state


def scan_directory(watch_dir: str, state: dict) -> dict:
    """Process all .txt files that are new or have been modified."""
    for path in sorted(Path(watch_dir).glob("*.txt")):
        path_str     = str(path)
        known_mtime  = state.get(path_str, {}).get("mtime", 0)
        current_mtime = path.stat().st_mtime
        if current_mtime > known_mtime:
            log.info("Detectado: %s", path.name)
            state = ingest_file(path_str, state)
    return state


# ── Watchdog handler ──────────────────────────────────────────────────────────

class LogHandler(FileSystemEventHandler):
    def __init__(self):
        self.state = load_state()

    def _handle(self, path: str) -> None:
        if not path.endswith(".txt"):
            return
        known_mtime   = self.state.get(path, {}).get("mtime", 0)
        current_mtime = os.path.getmtime(path)
        if current_mtime <= known_mtime:
            return
        self.state = ingest_file(path, self.state)
        save_state(self.state)

    def on_created(self, event):
        if not event.is_directory:
            log.info("Archivo nuevo: %s", os.path.basename(event.src_path))
            self._handle(event.src_path)

    def on_modified(self, event):
        if not event.is_directory:
            self._handle(event.src_path)


# ── Entry point ───────────────────────────────────────────────────────────────

def wait_for_api(retries: int = 30, delay: int = 3) -> None:
    for attempt in range(retries):
        try:
            requests.get(f"{API_URL}/health", timeout=3)
            log.info("API lista: %s", API_URL)
            return
        except requests.RequestException:
            log.info("Esperando API... (%d/%d)", attempt + 1, retries)
            time.sleep(delay)
    log.warning("API no respondió; continuando de todas formas")


def main() -> None:
    watch_dir = os.path.abspath(WATCH_DIR)
    os.makedirs(watch_dir, exist_ok=True)

    log.info("Directorio: %s", watch_dir)
    log.info("API:        %s", API_URL)

    wait_for_api()

    handler = LogHandler()

    # Process any files that arrived before the watcher started
    log.info("Escaneando archivos existentes...")
    handler.state = scan_directory(watch_dir, handler.state)
    save_state(handler.state)

    observer = Observer()
    observer.schedule(handler, watch_dir, recursive=False)
    observer.start()
    log.info("Watcher activo — esperando cambios en %s", watch_dir)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Deteniendo watcher...")
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
