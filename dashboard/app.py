import os
import time
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from datetime import datetime

API_URL = os.getenv("API_URL", "http://localhost:8000")

# ── Palette ───────────────────────────────────────────────────────────────────
C_BG       = "#070B14"
C_CARD     = "#0D1526"
C_BORDER   = "#1E3A8A"
C_TEXT     = "#E2E8F0"
C_MUTED    = "#64748B"
C_BLUE     = "#3B82F6"
C_GREEN    = "#22C55E"
C_AMBER    = "#F59E0B"
C_RED      = "#EF4444"
C_SLATE    = "#475569"

PLOTLY_DARK = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
    font=dict(color=C_TEXT, family="Fira Sans, sans-serif"),
    margin=dict(t=10, b=10, l=10, r=10),
)

def hex_rgba(hex_color: str, alpha: float = 0.08) -> str:
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r},{g},{b},{alpha})"


CAT_COLOR = {
    "Productiva":  C_GREEN,
    "Distracción": C_AMBER,
    "Peligrosa":   C_RED,
    "Neutra":      C_SLATE,
}

st.set_page_config(
    page_title="MonitorDB — Productividad",
    layout="wide",
    page_icon="◈",
    initial_sidebar_state="expanded",
)

# ── Global CSS ────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Fira+Sans:wght@300;400;500;600;700&display=swap');

html, body, [class*="css"] { font-family: 'Fira Sans', sans-serif; }

#MainMenu, footer, header { visibility: hidden; }
.block-container { padding-top: 1.5rem; padding-bottom: 1rem; max-width: 1400px; }

.kpi-card {
    background: #0D1526;
    border: 1px solid #1E3A8A;
    border-radius: 12px;
    padding: 1.2rem 1.4rem;
    position: relative;
    overflow: hidden;
}
.kpi-card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 3px;
    background: linear-gradient(90deg, #1E40AF, #3B82F6);
}
.kpi-card.green::before  { background: linear-gradient(90deg, #15803D, #22C55E); }
.kpi-card.amber::before  { background: linear-gradient(90deg, #B45309, #F59E0B); }
.kpi-card.red::before    { background: linear-gradient(90deg, #991B1B, #EF4444); }
.kpi-card.slate::before  { background: linear-gradient(90deg, #334155, #64748B); }

.kpi-label {
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: #64748B;
    margin-bottom: 0.4rem;
}
.kpi-value {
    font-family: 'Fira Code', monospace;
    font-size: 2rem;
    font-weight: 600;
    color: #E2E8F0;
    line-height: 1;
}
.kpi-sub {
    font-size: 0.75rem;
    color: #475569;
    margin-top: 0.35rem;
}

.section-title {
    font-size: 0.8rem;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: #3B82F6;
    margin-bottom: 0.5rem;
    padding-bottom: 0.4rem;
    border-bottom: 1px solid #1E3A8A;
}

.upload-badge {
    background: #0D1526;
    border: 1px dashed #1E3A8A;
    border-radius: 8px;
    padding: 0.8rem;
    text-align: center;
    font-size: 0.8rem;
    color: #64748B;
}

.live-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    background: #0D2010;
    border: 1px solid #15803D;
    border-radius: 20px;
    padding: 0.2rem 0.7rem;
    font-size: 0.7rem;
    font-weight: 600;
    color: #22C55E;
    letter-spacing: 0.06em;
}
.live-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #22C55E;
    animation: pulse 1.5s infinite;
}
@keyframes pulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.3; }
}

[data-testid="stSidebar"] {
    background: #0D1526;
    border-right: 1px solid #1E3A8A;
}
[data-testid="stSidebar"] .stButton > button {
    background: #1E40AF;
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    width: 100%;
    transition: background 200ms;
}
[data-testid="stSidebar"] .stButton > button:hover {
    background: #2563EB;
    cursor: pointer;
}

hr { border-color: #1E3A8A !important; }
[data-testid="stDataFrame"] { border-radius: 8px; overflow: hidden; }
</style>
""", unsafe_allow_html=True)


# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown('<div class="section-title">◈ MonitorDB</div>', unsafe_allow_html=True)
    st.markdown('<p style="color:#64748B;font-size:0.8rem;margin-bottom:1rem">Análisis de Productividad Corporativa</p>', unsafe_allow_html=True)

    st.markdown('<div class="section-title">Cargar Logs</div>', unsafe_allow_html=True)
    uploaded = st.file_uploader("Archivo .txt del router", type=["txt"], label_visibility="collapsed")
    if uploaded and st.button("Ingestar logs"):
        with st.spinner("Procesando..."):
            resp = requests.post(
                f"{API_URL}/api/logs/upload",
                files={"file": (uploaded.name, uploaded.getvalue(), "text/plain")},
            )
        if resp.ok:
            r = resp.json()
            st.success(f"✓ {r['processed']} líneas procesadas")
            st.caption(f"Upsert: {r['upserted']} · Apps nuevas: {r['new_apps']} · Omitidas: {r['skipped']}")
            st.cache_data.clear()
        else:
            st.error(f"Error {resp.status_code}: {resp.text}")

    st.divider()
    if st.button("Refrescar datos"):
        st.cache_data.clear()
        st.rerun()

    st.markdown(f'<p style="color:#334155;font-size:0.7rem;margin-top:1rem">API: {API_URL}</p>', unsafe_allow_html=True)
    st.markdown('<p style="color:#334155;font-size:0.7rem">Auto-refresh: 30s</p>', unsafe_allow_html=True)


# ── Data loaders ─────────────────────────────────────────────────────────────
@st.cache_data(ttl=30)
def get(endpoint: str):
    resp = requests.get(f"{API_URL}{endpoint}", timeout=10)
    resp.raise_for_status()
    return resp.json()


# ── Live dashboard (auto-refreshes every 30s) ─────────────────────────────────
@st.fragment(run_every=30)
def render_dashboard():
    try:
        resumen    = get("/api/kpis/resumen")
        dep_data   = get("/api/kpis/por_departamento")
        top_data   = get("/api/kpis/top_apps")
        trend_data = get("/api/kpis/tendencia_diaria")
        emp_data   = get("/api/kpis/empleados")
    except Exception as e:
        st.error(f"Sin conexión a API: {e}")
        return

    df_dep   = pd.DataFrame(dep_data)
    df_top   = pd.DataFrame(top_data)
    df_trend = pd.DataFrame(trend_data)
    df_emp   = pd.DataFrame(emp_data)

    # Live badge + last updated
    ts = datetime.now().strftime("%H:%M:%S")
    st.markdown(
        f'<div style="display:flex;align-items:center;gap:1rem;margin-bottom:1rem">'
        f'<span class="live-badge"><span class="live-dot"></span>EN VIVO</span>'
        f'<span style="color:#334155;font-size:0.72rem">Actualizado: {ts}</span>'
        f'</div>',
        unsafe_allow_html=True,
    )

    # ── KPI Cards ─────────────────────────────────────────────────────────────
    pct_prod = resumen.get("pct_productivo") or 0
    pct_dist = resumen.get("pct_distraccion") or 0
    pct_peli = resumen.get("pct_peligroso") or 0
    emp_act  = resumen.get("empleados_activos") or 0
    dias     = resumen.get("dias_con_datos") or 0
    min_tot  = resumen.get("min_total") or 0
    horas    = round(min_tot / 60, 1)

    c1, c2, c3, c4, c5 = st.columns(5)
    cards = [
        (c1, "Empleados Activos", emp_act,  f"{dias} días con datos", "blue"),
        (c2, "Horas Totales",     f"{horas}h", f"{min_tot:,} minutos",  "slate"),
        (c3, "% Productivo",      f"{pct_prod}%", "tiempo en apps útiles", "green"),
        (c4, "% Distracción",     f"{pct_dist}%", "RRSS y entretenimiento", "amber"),
        (c5, "% Peligroso",       f"{pct_peli}%", "sitios bloqueados",       "red"),
    ]
    for col, label, value, sub, color in cards:
        with col:
            st.markdown(f"""
            <div class="kpi-card {color}">
                <div class="kpi-label">{label}</div>
                <div class="kpi-value">{value}</div>
                <div class="kpi-sub">{sub}</div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # ── Row 1: Gauges + Departamentos ─────────────────────────────────────────
    col_gauge, col_dep = st.columns([1, 2])

    with col_gauge:
        st.markdown('<div class="section-title">Indicadores Clave</div>', unsafe_allow_html=True)

        def gauge(value, label, color):
            fig = go.Figure(go.Indicator(
                mode="gauge+number",
                value=value,
                number={"suffix": "%", "font": {"size": 28, "color": C_TEXT, "family": "Fira Code"}},
                title={"text": label, "font": {"size": 11, "color": C_MUTED}},
                gauge={
                    "axis": {"range": [0, 100], "tickcolor": C_MUTED, "tickwidth": 1,
                              "tickfont": {"size": 9, "color": C_MUTED}},
                    "bar": {"color": color, "thickness": 0.25},
                    "bgcolor": "#0D1526",
                    "bordercolor": C_BORDER,
                    "borderwidth": 1,
                    "steps": [
                        {"range": [0, 40],  "color": "#0D1526"},
                        {"range": [40, 70], "color": "#111827"},
                        {"range": [70, 100],"color": "#0F2518"},
                    ],
                    "threshold": {"line": {"color": color, "width": 2}, "value": value},
                },
            ))
            fig.update_layout(**PLOTLY_DARK, height=200)
            return fig

        g1, g2 = st.columns(2)
        g1.plotly_chart(gauge(pct_prod, "PRODUCTIVO", C_GREEN), use_container_width=True)
        g2.plotly_chart(gauge(pct_dist, "DISTRACCIÓN", C_AMBER), use_container_width=True)

    with col_dep:
        st.markdown('<div class="section-title">Minutos por Departamento</div>', unsafe_allow_html=True)
        if not df_dep.empty:
            fig_dep = go.Figure()
            for col_key, color, label in [
                ("min_productivos",   C_GREEN, "Productivo"),
                ("min_distracciones", C_AMBER, "Distracción"),
                ("min_peligrosos",    C_RED,   "Peligroso"),
            ]:
                fig_dep.add_bar(
                    x=df_dep["departamento"],
                    y=df_dep[col_key],
                    name=label,
                    marker=dict(color=color, opacity=0.85),
                    hovertemplate="%{x}<br>%{y} min<extra></extra>",
                )
            fig_dep.update_layout(
                **PLOTLY_DARK,
                barmode="stack",
                height=400,
                legend=dict(orientation="h", y=-0.15, font=dict(size=11, color=C_MUTED)),
                xaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER),
                yaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER, title="minutos"),
            )
            st.plotly_chart(fig_dep, use_container_width=True)
        else:
            st.info("Sin datos de departamentos")

    st.divider()

    # ── Row 2: Tendencia ──────────────────────────────────────────────────────
    st.markdown('<div class="section-title">Tendencia Diaria</div>', unsafe_allow_html=True)
    if not df_trend.empty:
        df_trend["fecha"] = pd.to_datetime(df_trend["fecha"])
        fig_trend = go.Figure()
        for col_key, color, label in [
            ("min_productivos",   C_GREEN, "Productivo"),
            ("min_distracciones", C_AMBER, "Distracción"),
            ("min_peligrosos",    C_RED,   "Peligroso"),
        ]:
            fig_trend.add_scatter(
                x=df_trend["fecha"],
                y=df_trend[col_key],
                mode="lines+markers",
                name=label,
                line=dict(color=color, width=2),
                fill="tozeroy",
                fillcolor=hex_rgba(color),
                marker=dict(size=5, color=color),
                hovertemplate="%{x|%d %b}<br>%{y} min<extra>" + label + "</extra>",
            )
        fig_trend.update_layout(
            **PLOTLY_DARK,
            height=260,
            legend=dict(orientation="h", y=-0.2, font=dict(size=11, color=C_MUTED)),
            xaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER),
            yaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER, title="minutos"),
            hovermode="x unified",
        )
        st.plotly_chart(fig_trend, use_container_width=True)
    else:
        st.info("Sin datos de tendencia")

    st.divider()

    # ── Row 3: Top Apps + Empleados ───────────────────────────────────────────
    col_apps, col_emp = st.columns(2)

    with col_apps:
        st.markdown('<div class="section-title">Top 10 Aplicaciones</div>', unsafe_allow_html=True)
        if not df_top.empty:
            df10 = df_top.head(10).copy()
            df10["color"] = df10["categoria"].map(CAT_COLOR).fillna(C_SLATE)
            fig_apps = go.Figure(go.Bar(
                x=df10["minutos"],
                y=df10["app"],
                orientation="h",
                marker=dict(color=df10["color"].tolist(), opacity=0.85, line=dict(width=0)),
                hovertemplate="%{y}<br>%{x} min<extra></extra>",
                text=df10["minutos"].apply(lambda m: f"{m}m"),
                textposition="outside",
                textfont=dict(size=10, color=C_MUTED),
            ))
            fig_apps.update_layout(
                **PLOTLY_DARK,
                height=380,
                xaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER, title="minutos"),
                yaxis=dict(autorange="reversed", linecolor=C_BORDER),
            )
            st.plotly_chart(fig_apps, use_container_width=True)

    with col_emp:
        st.markdown('<div class="section-title">Productividad por Empleado</div>', unsafe_allow_html=True)
        if not df_emp.empty:
            df_e = df_emp.copy()
            df_e["color"] = df_e["pct_productivo"].apply(
                lambda v: C_RED if v < 40 else (C_AMBER if v < 60 else C_GREEN)
            )
            fig_emp = go.Figure(go.Bar(
                x=df_e["pct_productivo"],
                y=df_e["nombre"],
                orientation="h",
                marker=dict(color=df_e["color"].tolist(), opacity=0.85, line=dict(width=0)),
                hovertemplate="%{y}<br>%{x:.1f}%<extra></extra>",
                text=df_e["pct_productivo"].apply(lambda v: f"{v:.0f}%"),
                textposition="outside",
                textfont=dict(size=10, color=C_MUTED),
            ))
            fig_emp.add_vline(
                x=60, line_dash="dash", line_color=C_BLUE, line_width=1,
                annotation_text="Meta 60%",
                annotation_font=dict(color=C_BLUE, size=10),
                annotation_position="top right",
            )
            fig_emp.update_layout(
                **PLOTLY_DARK,
                height=380,
                xaxis=dict(gridcolor="#1E293B", linecolor=C_BORDER, range=[0, 110], title="% productivo"),
                yaxis=dict(autorange="reversed", linecolor=C_BORDER),
            )
            st.plotly_chart(fig_emp, use_container_width=True)

    st.divider()

    # ── Distribución global (donut) ───────────────────────────────────────────
    col_donut, col_table = st.columns([1, 2])

    with col_donut:
        st.markdown('<div class="section-title">Distribución Global</div>', unsafe_allow_html=True)
        labels = ["Productivo", "Distracción", "Peligroso", "Neutra"]
        values = [
            resumen.get("min_productivos") or 0,
            resumen.get("min_distracciones") or 0,
            resumen.get("min_peligrosos") or 0,
            resumen.get("min_neutra") or 0,
        ]
        fig_donut = go.Figure(go.Pie(
            labels=labels,
            values=values,
            marker=dict(colors=[C_GREEN, C_AMBER, C_RED, C_SLATE],
                        line=dict(color=C_BG, width=2)),
            hole=0.55,
            textinfo="percent",
            textfont=dict(size=12),
            hovertemplate="%{label}<br>%{value} min (%{percent})<extra></extra>",
        ))
        fig_donut.add_annotation(
            text=f"<b>{pct_prod}%</b><br><span style='font-size:10px'>productivo</span>",
            x=0.5, y=0.5, showarrow=False,
            font=dict(size=18, color=C_GREEN, family="Fira Code"),
        )
        fig_donut.update_layout(
            **PLOTLY_DARK,
            height=320,
            showlegend=True,
            legend=dict(orientation="h", y=-0.15, font=dict(size=11, color=C_MUTED)),
        )
        st.plotly_chart(fig_donut, use_container_width=True)

    with col_table:
        st.markdown('<div class="section-title">Detalle Empleados</div>', unsafe_allow_html=True)
        if not df_emp.empty:
            display = df_emp[["nombre", "departamento", "min_productivos", "min_distracciones", "min_peligrosos", "pct_productivo"]].copy()
            display.columns = ["Empleado", "Depto", "Min Prod", "Min Dist", "Min Peligr", "% Prod"]
            def _pct_style(col):
                return [
                    "background-color:rgba(21,128,61,0.15);color:#22C55E" if v >= 60
                    else "background-color:rgba(180,83,9,0.15);color:#F59E0B" if v >= 40
                    else "background-color:rgba(153,27,27,0.15);color:#EF4444"
                    for v in col
                ]
            st.dataframe(
                display.style.apply(_pct_style, subset=["% Prod"]),
                use_container_width=True,
                height=320,
            )

    # ── Raw data expander ─────────────────────────────────────────────────────
    with st.expander("Datos crudos"):
        t1, t2, t3 = st.tabs(["Apps", "Tendencia", "Departamentos"])
        with t1:
            st.dataframe(df_top, use_container_width=True)
        with t2:
            st.dataframe(df_trend, use_container_width=True)
        with t3:
            st.dataframe(df_dep, use_container_width=True)


render_dashboard()
