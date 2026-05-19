-- ============================================
-- CARGAR DATOS DE EJEMPLO DESDE LOGS
-- ============================================

USE productividad_corporativa;

-- Insertar accesos desde log 2026-05-13
-- Dispositivo 1: POCO-X7-Pro (5E-DF-77-99-D6-5E) - Empleado 1
INSERT INTO accesos_diarios (empleado_id, app_id, fecha, minutos_totales, numero_accesos, primer_acceso, ultimo_acceso) VALUES
(1, (SELECT app_id FROM aplicaciones WHERE dominio='connectivitycheck.gstatic.com'), '2026-05-13', 5, 3, '19:19:56', '19:20:00'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='mtalk.google.com'), '2026-05-13', 2, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='spot-pa.googleapis.com'), '2026-05-13', 1, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='sdkconfig.ad.intl.xiaomi.com'), '2026-05-13', 1, 1, '19:19:58', '19:19:58'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='resolver.msg.global.xiaomi.net'), '2026-05-13', 1, 1, '19:19:59', '19:19:59'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='tiktok.com'), '2026-05-13', 5, 3, '19:19:59', '19:20:00'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='facebook.com'), '2026-05-13', 1, 1, '19:19:59', '19:19:59'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='google.com'), '2026-05-13', 2, 1, '19:20:30', '19:20:30'),
(1, (SELECT app_id FROM aplicaciones WHERE dominio='reddit.com'), '2026-05-13', 15, 2, '19:20:45', '19:20:45'),

-- Dispositivo 2: A56-de-Luis (06-43-9E-71-92-EF) - Empleado 2
(2, (SELECT app_id FROM aplicaciones WHERE dominio='connectivitycheck.gstatic.com'), '2026-05-13', 10, 5, '19:21:20', '20:05:56'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='google.com'), '2026-05-13', 20, 10, '19:21:21', '20:05:49'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='gmail.com'), '2026-05-13', 45, 3, '19:27:00', '20:00:52'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='netflix.com'), '2026-05-13', 90, 8, '19:21:25', '19:27:27'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='tiktok.com'), '2026-05-13', 30, 5, '19:21:40', '19:27:10'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='facebook.com'), '2026-05-13', 15, 2, '19:21:29', '19:27:08'),
(2, (SELECT app_id FROM aplicaciones WHERE dominio='youtube.com'), '2026-05-13', 60, 6, '19:21:25', '20:05:59');

-- ============================================
-- CALCULAR KPI MENSUAL POR DEPARTAMENTO
-- ============================================

INSERT INTO kpi_mensual (
  departamento_id, mes, total_empleados_activos,
  total_minutos_productivos, total_minutos_distracciones, total_minutos_neutra,
  porcentaje_productivo, porcentaje_distraccion,
  app_top_1, app_top_1_minutos,
  app_top_2, app_top_2_minutos,
  app_top_3, app_top_3_minutos
)
SELECT
  d.departamento_id,
  DATE_FORMAT(CURDATE(), '%Y-%m-01') as mes,
  COUNT(DISTINCT e.empleado_id) as total_empleados_activos,
  SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END) as total_productivos,
  SUM(CASE WHEN ca.nombre='Distracción' THEN ad.minutos_totales ELSE 0 END) as total_distracciones,
  SUM(CASE WHEN ca.nombre='Neutra' THEN ad.minutos_totales ELSE 0 END) as total_neutra,
  ROUND(SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END) /
        NULLIF(SUM(ad.minutos_totales), 0) * 100, 2) as porcentaje_prod,
  ROUND(SUM(CASE WHEN ca.nombre='Distracción' THEN ad.minutos_totales ELSE 0 END) /
        NULLIF(SUM(ad.minutos_totales), 0) * 100, 2) as porcentaje_dist,
  (SELECT a.nombre_app FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1) as app_top_1,
  (SELECT SUM(ad2.minutos_totales) FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1) as app_top_1_min,
  (SELECT a.nombre_app FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1 OFFSET 1) as app_top_2,
  (SELECT SUM(ad2.minutos_totales) FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1 OFFSET 1) as app_top_2_min,
  (SELECT a.nombre_app FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1 OFFSET 2) as app_top_3,
  (SELECT SUM(ad2.minutos_totales) FROM accesos_diarios ad2
   JOIN aplicaciones a ON ad2.app_id = a.app_id
   WHERE ad2.empleado_id IN (SELECT empleado_id FROM empleados WHERE departamento_id = d.departamento_id)
   GROUP BY a.app_id ORDER BY SUM(ad2.minutos_totales) DESC LIMIT 1 OFFSET 2) as app_top_3_min
FROM departamentos d
JOIN empleados e ON d.departamento_id = e.departamento_id
JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
JOIN aplicaciones a ON ad.app_id = a.app_id
JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE MONTH(ad.fecha) = MONTH(CURDATE()) AND YEAR(ad.fecha) = YEAR(CURDATE())
GROUP BY d.departamento_id
ON DUPLICATE KEY UPDATE
  total_empleados_activos = VALUES(total_empleados_activos),
  total_minutos_productivos = VALUES(total_minutos_productivos),
  porcentaje_productivo = VALUES(porcentaje_productivo);

-- ============================================
-- DETECTAR ALERTAS
-- ============================================

INSERT INTO alertas (empleado_id, tipo, descripcion)
SELECT DISTINCT
  e.empleado_id,
  'Exceso_Distraccion',
  CONCAT('Empleado gastó ',
    (SELECT SUM(ad2.minutos_totales) FROM accesos_diarios ad2
     JOIN aplicaciones a2 ON ad2.app_id = a2.app_id
     JOIN categorias_app ca2 ON a2.categoria_id = ca2.categoria_id
     WHERE ad2.empleado_id = e.empleado_id AND ca2.nombre = 'Distracción' AND DATE(ad2.fecha) = CURDATE()),
    ' minutos en apps de distracción hoy')
FROM empleados e
JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
JOIN aplicaciones a ON ad.app_id = a.app_id
JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE ca.nombre = 'Distracción'
  AND DATE(ad.fecha) = CURDATE()
GROUP BY e.empleado_id
HAVING SUM(ad.minutos_totales) > 60
ON DUPLICATE KEY UPDATE resuelta = 0;

-- ============================================
-- VERIFICAR DATOS
-- ============================================

SELECT 'Verificación BD Creada' as Status;
SELECT COUNT(*) as Total_Accesos FROM accesos_diarios;
SELECT COUNT(*) as Total_Aplicaciones FROM aplicaciones;
SELECT COUNT(*) as Total_Empleados FROM empleados;
SELECT COUNT(*) as Total_Alertas FROM alertas;
