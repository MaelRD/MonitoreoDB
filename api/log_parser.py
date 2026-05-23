import re
from datetime import datetime
from typing import Optional


def extract_domain(raw_url: str) -> str:
    url = raw_url.strip()
    url = re.sub(r"^https?://", "", url)
    domain = url.split("/")[0].split(":")[0]
    return domain.lower()


def parse_line(line: str) -> Optional[dict]:
    """Parse one log line into a dict.

    Format: timestamp<TAB>vlan<TAB>network<TAB>device<TAB>mac<TAB>url<TAB>port
    Example: 13.05.2026 19:19:56\t4\tGuest\tPOCO-X7-Pro\t5E-DF-77-99-D6-5E\thttp://x.com\t80
    """
    parts = line.strip().split("\t")
    if len(parts) < 6:
        return None
    try:
        ts = datetime.strptime(parts[0].strip(), "%d.%m.%Y %H:%M:%S")
    except ValueError:
        return None

    domain = extract_domain(parts[5])
    if not domain:
        return None

    return {
        "timestamp": ts,
        "date": ts.date(),
        "time": ts.time(),
        "mac": parts[4].strip().upper(),
        "domain": domain,
    }


def parse_content(content: str) -> list[dict]:
    records = []
    for line in content.splitlines():
        if not line.strip():
            continue
        rec = parse_line(line)
        if rec:
            records.append(rec)
    return records
