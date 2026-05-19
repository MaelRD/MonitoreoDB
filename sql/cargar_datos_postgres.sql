-- ============================================
-- CARGAR DATOS DE EJEMPLO DESDE LOGS (PostgreSQL)
-- ============================================

\c productividad_corporativa;

-- Crear usuario api para PostgREST
CREATE ROLE api_user LOGIN PASSWORD 'api_pass' NOINHERIT;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_user;

-- ============================================
-- INSERTAR ACCESOS DESDE LOGS
-- ============================================

INSERT INTO accesos_diarios (empleado_id, app_id, fecha, minutos_totales, numero_accesos, primer_acceso, ultimo_acceso)
VALUES
-- Dispositivo 1: POCO-X7-Pro - Empleado Carlos García
(1, (SELECT app_id FROM aplicaciones WHERE dominio='connectivitycheck.gstatic.com'), '2026-05-13', 5, 3, '19:19:56', '19:20:00'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='mtalk.google.com'), '2026-05-13', 2, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='spot-pa.googleapis.com'), '2026-05-13', 1, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='sdkconfig.ad.intl.xiaomi.com'), '2026-05-13', 1, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='resolver.msg.global.xiaomi.net'), '2026-05-13', 1, 1, '19:19:59', '19:19:59'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='tiktok.com'), '2026-05-13', 5, 3, '19:19:59', '19:20:00'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='facebook.com'), '2026-05-13', 1, 1, '19:19:59', '19:19:59'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='google.com'), '2026-05-13', 2, 1, '19:20:30', '19:20:30'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='reddit.com'), '2026-05-13', 15, 2, '19:20:45', '19:20:45'),

-- Dispositivo 2: A56-de-Luis - Empleado María López
(2, (SELECT app_id FROM aplicaciones WHERE dominio='connectivitycheck.gstatic.com'), '2026-05-13', 10, 5, '19:21:20', '20:05:56'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='google.com'), '2026-05-13', 20, 10, '19:21:21', '20:05:49'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='gmail.com'), '2026-05-13', 45, 3, '19:27:00', '20:00:52'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='netflix.com'), '2026-05-13', 90, 8, '19:21:25', '19:27:27'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='tiktok.com'), '2026-05-13', 30, 5, '19:21:40', '19:27:10'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='facebook.com'), '2026-05-13', 15, 2, '19:21:29', '19:27:08'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='youtube.com'), '2026-05-13', 60, 6, '19:21:25', '20:05:59'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='slack.com'), '2026-05-13', 120, 15, '19:30:00', '20:30:00'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='docs.google.com'), '2026-05-13', 80, 10, '19:40:00', '20:40:00');

-- ============================================
-- CREAR VISTA DE KPI MENSUAL (ej. útil para PostgREST)
-- ============================================

CREATE OR REPLACE VIEW v_kpi_mensual_actual AS
SELECT
  d.departamento_id,
  d.nombre AS departamento,
  COUNT(DISTINCT e.empleado_id) as total_empleados,
  SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END) as minutos_productivos,
  SUM(CASE WHEN ca.nombre='Distracción' THEN ad.minutos_totales ELSE 0 END) as minutos_distracciones,
  ROUND(SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END)::numeric /
        NULLIF(SUM(ad.minutos_totales), 0) * 100, 2) as porcentaje_productivo
FROM departamentos d
LEFT JOIN empleados e ON d.departamento_id = e.departamento_id
LEFT JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
LEFT JOIN aplicaciones a ON ad.app_id = a.app_id
LEFT JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE EXTRACT(MONTH FROM ad.fecha) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM ad.fecha) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY d.departamento_id, d.nombre;

-- ============================================
-- CREAR VISTA DE EMPLEADOS CON CONSUMO
-- ============================================

CREATE OR REPLACE VIEW v_empleado_consumo AS
SELECT
  e.empleado_id,
  e.nombre,
  e.email,
  d.nombre AS departamento,
  SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END) as minutos_productivos,
  SUM(CASE WHEN ca.nombre='Distracción' THEN ad.minutos_totales ELSE 0 END) as minutos_distracciones,
  ROUND(SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END)::numeric /
        NULLIF(SUM(ad.minutos_totales), 0) * 100, 2) as porcentaje_productivo,
  COUNT(DISTINCT ad.fecha) as dias_activos
FROM empleados e
LEFT JOIN departamentos d ON e.departamento_id = d.departamento_id
LEFT JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
LEFT JOIN aplicaciones a ON ad.app_id = a.app_id
LEFT JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE EXTRACT(MONTH FROM ad.fecha) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM ad.fecha) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY e.empleado_id, e.nombre, e.email, d.nombre;

-- ============================================
-- CREAR VISTA DE TOP APPS
-- ============================================

CREATE OR REPLACE VIEW v_top_apps_por_categoria AS
SELECT
  ca.nombre AS categoria,
  a.nombre_app,
  SUM(ad.minutos_totales) as minutos_totales,
  COUNT(DISTINCT ad.empleado_id) as empleados_que_usan,
  RANK() OVER (PARTITION BY ca.nombre ORDER BY SUM(ad.minutos_totales) DESC) as posicion
FROM accesos_diarios ad
JOIN aplicaciones a ON ad.app_id = a.app_id
JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE EXTRACT(MONTH FROM ad.fecha) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM ad.fecha) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY ca.nombre, a.app_id, a.nombre_app;

-- ============================================
-- GENERAR ALERTAS
-- ============================================

INSERT INTO alertas (empleado_id, tipo, descripcion)
SELECT DISTINCT
  e.empleado_id,
  'Exceso_Distraccion'::tipo_alerta,
  'Empleado gastó más de 60 minutos en apps de distracción hoy'
FROM empleados e
JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
JOIN aplicaciones a ON ad.app_id = a.app_id
JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE ca.nombre = 'Distracción'
  AND DATE(ad.fecha) = CURRENT_DATE
GROUP BY e.empleado_id
HAVING SUM(ad.minutos_totales) > 60
ON CONFLICT DO NOTHING;

-- ============================================
-- GRANT PERMISOS FINALES
-- ============================================

GRANT SELECT ON v_kpi_mensual_actual TO api_user;
GRANT SELECT ON v_empleado_consumo TO api_user;
GRANT SELECT ON v_top_apps_por_categoria TO api_user;

-- ============================================
-- VERIFICACIÓN
-- ============================================

SELECT COUNT(*) as total_accesos FROM accesos_diarios;
SELECT COUNT(*) as total_empleados FROM empleados;
SELECT COUNT(*) as total_aplicaciones FROM aplicaciones;
SELECT COUNT(*) as total_alertas FROM alertas;
