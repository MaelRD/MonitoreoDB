"""Parse log records and upsert into accesos_diarios."""
from collections import defaultdict
from datetime import datetime

from api.db import get_conn


def ingest(records: list[dict]) -> dict:
    if not records:
        return {"processed": 0, "upserted": 0, "new_apps": 0, "skipped": 0}

    conn = get_conn()
    cur = conn.cursor()

    upserted = 0
    new_apps = 0
    skipped = 0

    # Group by (mac, domain, date) to aggregate before upsert
    groups: dict[tuple, list] = defaultdict(list)
    for r in records:
        groups[(r["mac"], r["domain"], r["date"])].append(r)

    for (mac, domain, day), events in groups.items():
        # Resolve device → empleado
        cur.execute(
            "SELECT empleado_id FROM dispositivos WHERE mac_address = %s AND activo = TRUE",
            (mac,),
        )
        row = cur.fetchone()
        if not row:
            skipped += len(events)
            continue
        empleado_id = row["empleado_id"]

        # Resolve or create app
        cur.execute("SELECT app_id FROM aplicaciones WHERE dominio = %s", (domain,))
        row = cur.fetchone()
        if not row:
            cur.execute(
                """
                INSERT INTO aplicaciones (dominio, nombre_app, categoria_id)
                SELECT %s, %s, categoria_id FROM categorias_app WHERE nombre = 'Neutra'
                RETURNING app_id
                """,
                (domain, domain),
            )
            row = cur.fetchone()
            new_apps += 1
        app_id = row["app_id"]

        # Calculate time stats
        times = sorted(e["time"] for e in events)
        primer = times[0]
        ultimo = times[-1]
        num_accesos = len(events)
        dt_first = datetime.combine(day, primer)
        dt_last = datetime.combine(day, ultimo)
        minutos = max(1, int((dt_last - dt_first).total_seconds() / 60) + 1)

        # Upsert — accumulate on conflict
        cur.execute(
            """
            INSERT INTO accesos_diarios
                (empleado_id, app_id, fecha, minutos_totales, numero_accesos, primer_acceso, ultimo_acceso)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (empleado_id, app_id, fecha) DO UPDATE SET
                minutos_totales  = accesos_diarios.minutos_totales  + EXCLUDED.minutos_totales,
                numero_accesos   = accesos_diarios.numero_accesos   + EXCLUDED.numero_accesos,
                primer_acceso    = LEAST(accesos_diarios.primer_acceso, EXCLUDED.primer_acceso),
                ultimo_acceso    = GREATEST(accesos_diarios.ultimo_acceso, EXCLUDED.ultimo_acceso)
            """,
            (empleado_id, app_id, day, minutos, num_accesos, primer, ultimo),
        )
        upserted += 1

    conn.commit()
    cur.close()
    conn.close()

    return {
        "processed": len(records),
        "upserted": upserted,
        "new_apps": new_apps,
        "skipped": skipped,
    }
