from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from api.log_parser import parse_content
from api.ingestion import ingest
from api.db import get_conn

app = FastAPI(title="MonitorDB Log Ingestion API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/logs/upload")
async def upload_logs(file: UploadFile = File(...)):
    """Upload a .txt router log file and ingest into accesos_diarios."""
    if not file.filename.endswith(".txt"):
        raise HTTPException(400, "Only .txt log files accepted")

    content = (await file.read()).decode("utf-8", errors="replace")
    records = parse_content(content)

    if not records:
        raise HTTPException(422, "No valid log lines found in file")

    result = ingest(records)
    result["filename"] = file.filename
    return result


@app.get("/api/kpis/resumen")
def kpi_resumen():
    """Global KPI summary across all dates."""
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            SUM(CASE WHEN ca.nombre = 'Productiva'   THEN ad.minutos_totales ELSE 0 END) AS min_productivos,
            SUM(CASE WHEN ca.nombre = 'Distracción'  THEN ad.minutos_totales ELSE 0 END) AS min_distracciones,
            SUM(CASE WHEN ca.nombre = 'Peligrosa'    THEN ad.minutos_totales ELSE 0 END) AS min_peligrosos,
            SUM(CASE WHEN ca.nombre = 'Neutra'       THEN ad.minutos_totales ELSE 0 END) AS min_neutra,
            SUM(ad.minutos_totales)                                                        AS min_total,
            COUNT(DISTINCT ad.empleado_id)                                                 AS empleados_activos,
            COUNT(DISTINCT ad.fecha)                                                       AS dias_con_datos
        FROM accesos_diarios ad
        JOIN aplicaciones   a  ON ad.app_id    = a.app_id
        JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
    """)
    row = dict(cur.fetchone())
    total = row["min_total"] or 1
    row["pct_productivo"]   = round((row["min_productivos"]   or 0) / total * 100, 1)
    row["pct_distraccion"]  = round((row["min_distracciones"] or 0) / total * 100, 1)
    row["pct_peligroso"]    = round((row["min_peligrosos"]    or 0) / total * 100, 1)
    cur.close()
    conn.close()
    return row


@app.get("/api/kpis/por_departamento")
def kpi_por_departamento():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            d.nombre AS departamento,
            SUM(CASE WHEN ca.nombre = 'Productiva'  THEN ad.minutos_totales ELSE 0 END) AS min_productivos,
            SUM(CASE WHEN ca.nombre = 'Distracción' THEN ad.minutos_totales ELSE 0 END) AS min_distracciones,
            SUM(CASE WHEN ca.nombre = 'Peligrosa'   THEN ad.minutos_totales ELSE 0 END) AS min_peligrosos,
            SUM(ad.minutos_totales) AS min_total,
            COUNT(DISTINCT ad.empleado_id) AS empleados
        FROM departamentos d
        JOIN empleados e      ON d.departamento_id = e.departamento_id
        JOIN accesos_diarios ad ON e.empleado_id   = ad.empleado_id
        JOIN aplicaciones a    ON ad.app_id        = a.app_id
        JOIN categorias_app ca ON a.categoria_id   = ca.categoria_id
        GROUP BY d.departamento_id, d.nombre
        ORDER BY min_total DESC
    """)
    rows = [dict(r) for r in cur.fetchall()]
    cur.close()
    conn.close()
    return rows


@app.get("/api/kpis/top_apps")
def top_apps(limit: int = 10):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            COALESCE(a.nombre_app, a.dominio) AS app,
            ca.nombre AS categoria,
            SUM(ad.minutos_totales) AS minutos,
            SUM(ad.numero_accesos)  AS accesos,
            COUNT(DISTINCT ad.empleado_id) AS empleados
        FROM accesos_diarios ad
        JOIN aplicaciones   a  ON ad.app_id    = a.app_id
        JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
        GROUP BY a.app_id, a.nombre_app, a.dominio, ca.nombre
        ORDER BY minutos DESC
        LIMIT %s
    """, (limit,))
    rows = [dict(r) for r in cur.fetchall()]
    cur.close()
    conn.close()
    return rows


@app.get("/api/kpis/tendencia_diaria")
def tendencia_diaria():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            ad.fecha,
            SUM(CASE WHEN ca.nombre = 'Productiva'  THEN ad.minutos_totales ELSE 0 END) AS min_productivos,
            SUM(CASE WHEN ca.nombre = 'Distracción' THEN ad.minutos_totales ELSE 0 END) AS min_distracciones,
            SUM(CASE WHEN ca.nombre = 'Peligrosa'   THEN ad.minutos_totales ELSE 0 END) AS min_peligrosos
        FROM accesos_diarios ad
        JOIN aplicaciones   a  ON ad.app_id    = a.app_id
        JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
        GROUP BY ad.fecha
        ORDER BY ad.fecha
    """)
    rows = [dict(r) for r in cur.fetchall()]
    cur.close()
    conn.close()
    return rows


@app.get("/api/kpis/empleados")
def kpi_empleados():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            e.nombre,
            d.nombre AS departamento,
            SUM(CASE WHEN ca.nombre = 'Productiva'  THEN ad.minutos_totales ELSE 0 END) AS min_productivos,
            SUM(CASE WHEN ca.nombre = 'Distracción' THEN ad.minutos_totales ELSE 0 END) AS min_distracciones,
            SUM(CASE WHEN ca.nombre = 'Peligrosa'   THEN ad.minutos_totales ELSE 0 END) AS min_peligrosos,
            SUM(ad.minutos_totales) AS min_total,
            ROUND(
                SUM(CASE WHEN ca.nombre = 'Productiva' THEN ad.minutos_totales ELSE 0 END)::numeric
                / NULLIF(SUM(ad.minutos_totales), 0) * 100, 1
            ) AS pct_productivo
        FROM empleados e
        JOIN departamentos d    ON e.departamento_id  = d.departamento_id
        JOIN accesos_diarios ad ON e.empleado_id      = ad.empleado_id
        JOIN aplicaciones a     ON ad.app_id          = a.app_id
        JOIN categorias_app ca  ON a.categoria_id     = ca.categoria_id
        GROUP BY e.empleado_id, e.nombre, d.nombre
        ORDER BY pct_productivo DESC
    """)
    rows = [dict(r) for r in cur.fetchall()]
    cur.close()
    conn.close()
    return rows
