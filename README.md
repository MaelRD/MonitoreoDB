# PostgreSQL - Monitoreo BD

Base de datos relacional PostgreSQL 15 para análisis de productividad corporativa.

## Conexión Directa

### Desde Terminal

```bash
PGPASSWORD=postgres_pass psql \
  -h localhost \
  -U postgres \
  -d productividad_corporativa
```

### Datos de Conexión

| Parámetro | Valor |
|-----------|-------|
| Host | localhost |
| Puerto | 5432 |
| Usuario | postgres |
| Contraseña | postgres_pass |
| Base de datos | productividad_corporativa |

### Herramientas GUI

**pgAdmin** (recomendado)
- URL: http://localhost:5050
- Email: admin@example.com
- Contraseña: admin

## Estructura Base de Datos

### Tablas Principales

#### `departamentos`
Estructura organizacional de la empresa.

```sql
SELECT * FROM departamentos;
```

Campos: `departamento_id`, `nombre`, `descripcion`, `responsable`, `fecha_creacion`

#### `empleados`
Registro de empleados activos/inactivos por departamento.

```sql
SELECT nombre, email, departamento_id, estado FROM empleados;
```

Campos: `empleado_id`, `nombre`, `email`, `departamento_id`, `estado`, `fecha_ingreso`, `fecha_creacion`

Estados válidos: `Activo`, `Inactivo`, `Licencia`, `Suspendido`

#### `aplicaciones`
Catálogo de aplicaciones monitoreadas con categorización.

```sql
SELECT nombre_app, dominio, categoria_id FROM aplicaciones;
```

Campos: `app_id`, `nombre_app`, `dominio`, `categoria_id`, `descripcion`, `riesgo`, `fecha_creacion`

Categorías: `1=Productiva`, `2=Distracción`, `3=Peligrosa`

#### `accesos_diarios`
Serie temporal de consumo por empleado/app/día (datos principales).

```sql
SELECT 
  empleado_id, 
  app_id, 
  fecha, 
  minutos_totales, 
  numero_accesos 
FROM accesos_diarios 
WHERE fecha = CURRENT_DATE;
```

Campos: `acceso_id`, `empleado_id`, `app_id`, `fecha`, `minutos_totales`, `numero_accesos`, `primer_acceso`, `ultimo_acceso`, `fecha_creacion`

#### `dispositivos`
Mapeo de direcciones MAC a empleados (identificación de equipos).

```sql
SELECT empleado_id, mac_address, tipo_dispositivo FROM dispositivos;
```

Campos: `dispositivo_id`, `empleado_id`, `mac_address`, `tipo_dispositivo`, `modelo`, `fecha_registro`

#### `alertas`
Sistema de detección de anomalías y comportamientos riesgosos.

```sql
SELECT empleado_id, tipo_alerta, descripcion, resuelta FROM alertas WHERE resuelta = false;
```

Campos: `alerta_id`, `empleado_id`, `app_id`, `tipo_alerta`, `descripcion`, `fecha_alerta`, `resuelta`, `fecha_resolucion`, `nota_resolucion`

#### `kpi_mensual`
KPIs agregados por departamento (cálculos mensuales).

```sql
SELECT * FROM kpi_mensual WHERE mes = EXTRACT(MONTH FROM CURRENT_DATE);
```

Campos: `kpi_id`, `departamento_id`, `mes`, `año`, `total_empleados`, `minutos_totales_productivos`, `minutos_totales_distraccion`, `porcentaje_productivo`, `numero_alertas`, `fecha_calculo`

#### `auditoria_cambios`
Log de cambios en datos críticos (seguridad).

```sql
SELECT usuario, tabla, accion, fecha_cambio FROM auditoria_cambios ORDER BY fecha_cambio DESC LIMIT 20;
```

Campos: `auditoria_id`, `usuario`, `tabla`, `accion`, `registro_id`, `valor_anterior`, `valor_nuevo`, `fecha_cambio`

## Vistas Analíticas

### `v_kpi_mensual_actual`
KPI del mes actual por departamento.

```bash
curl -s http://localhost:3000/v_kpi_mensual_actual | jq .
```

```sql
SELECT 
  departamento_id,
  nombre_departamento,
  porcentaje_productivo,
  minutos_totales_productivos,
  minutos_totales_distraccion,
  numero_alertas
FROM v_kpi_mensual_actual;
```

### `v_empleado_consumo`
Consumo por empleado con productividad calculada.

```bash
curl -s http://localhost:3000/v_empleado_consumo?order=porcentaje_productivo.desc | jq .
```

```sql
SELECT 
  empleado_id,
  nombre_empleado,
  departamento,
  porcentaje_productivo,
  minutos_productivos,
  minutos_distraccion,
  minutos_peligrosos
FROM v_empleado_consumo
ORDER BY porcentaje_productivo DESC;
```

### `v_top_apps_por_categoria`
Aplicaciones más consumidas por categoría.

```bash
curl -s http://localhost:3000/v_top_apps_por_categoria?categoria=eq.Distracción | jq .
```

```sql
SELECT 
  nombre_app,
  categoria,
  minutos_totales,
  numero_accesos,
  posicion
FROM v_top_apps_por_categoria
WHERE categoria = 'Distracción'
ORDER BY posicion ASC;
```

## Consultas Comunes

### Empleados Bajo Productivos (<40%)

```sql
SELECT 
  e.nombre,
  e.email,
  d.nombre AS departamento,
  ec.porcentaje_productivo
FROM v_empleado_consumo ec
JOIN empleados e ON ec.empleado_id = e.empleado_id
JOIN departamentos d ON e.departamento_id = d.departamento_id
WHERE ec.porcentaje_productivo < 40
ORDER BY ec.porcentaje_productivo ASC;
```

### Apps Distractoras Top 10

```sql
SELECT 
  nombre_app,
  minutos_totales,
  numero_accesos,
  ROUND(100.0 * minutos_totales / SUM(minutos_totales) OVER (), 2) AS porcentaje
FROM aplicaciones a
JOIN accesos_diarios ad ON a.app_id = ad.app_id
WHERE a.categoria_id = 2
GROUP BY a.app_id, nombre_app
ORDER BY minutos_totales DESC
LIMIT 10;
```

### Alertas No Resueltas

```sql
SELECT 
  a.alerta_id,
  e.nombre,
  a.tipo_alerta,
  a.descripcion,
  a.fecha_alerta
FROM alertas a
JOIN empleados e ON a.empleado_id = e.empleado_id
WHERE a.resuelta = false
ORDER BY a.fecha_alerta DESC;
```

### Accesos Hoy por Empleado

```sql
SELECT 
  e.nombre,
  ap.nombre_app,
  SUM(ad.minutos_totales) AS minutos,
  COUNT(*) AS accesos
FROM accesos_diarios ad
JOIN empleados e ON ad.empleado_id = e.empleado_id
JOIN aplicaciones ap ON ad.app_id = ap.app_id
WHERE ad.fecha = CURRENT_DATE
GROUP BY e.empleado_id, e.nombre, ap.app_id, ap.nombre_app
ORDER BY minutos DESC;
```

### Productividad por Departamento (Mes Actual)

```sql
SELECT 
  d.nombre,
  km.total_empleados,
  km.porcentaje_productivo,
  km.minutos_totales_productivos,
  km.minutos_totales_distraccion,
  km.numero_alertas
FROM kpi_mensual km
JOIN departamentos d ON km.departamento_id = d.departamento_id
WHERE km.mes = EXTRACT(MONTH FROM CURRENT_DATE)
  AND km.año = EXTRACT(YEAR FROM CURRENT_DATE)
ORDER BY km.porcentaje_productivo DESC;
```

### Histórico Accesos Empleado (últimos 7 días)

```sql
SELECT 
  ad.fecha,
  ap.nombre_app,
  ap.categoria_id,
  SUM(ad.minutos_totales) AS minutos,
  COUNT(*) AS accesos
FROM accesos_diarios ad
JOIN aplicaciones ap ON ad.app_id = ap.app_id
WHERE ad.empleado_id = 1
  AND ad.fecha >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY ad.fecha, ap.app_id, ap.nombre_app, ap.categoria_id
ORDER BY ad.fecha DESC, minutos DESC;
```

## Operaciones DML

### Insertar Empleado

```sql
INSERT INTO empleados (nombre, email, departamento_id, estado)
VALUES ('Juan García', 'juan.garcia@empresa.com', 1, 'Activo')
RETURNING empleado_id;
```

### Actualizar Estado Empleado

```sql
UPDATE empleados
SET estado = 'Licencia'
WHERE empleado_id = 5;
```

### Agregar Dispositivo a Empleado

```sql
INSERT INTO dispositivos (empleado_id, mac_address, tipo_dispositivo, modelo)
VALUES (1, '00:1A:2B:3C:4D:5E', 'Laptop', 'MacBook Pro 15');
```

### Resolver Alerta

```sql
UPDATE alertas
SET resuelta = true,
    fecha_resolucion = NOW(),
    nota_resolucion = 'Empleado notificado y corregido'
WHERE alerta_id = 42;
```

### Insertar Acceso Diario

```sql
INSERT INTO accesos_diarios 
(empleado_id, app_id, fecha, minutos_totales, numero_accesos, primer_acceso, ultimo_acceso)
VALUES 
(1, 3, '2026-05-18', 120, 15, '09:30:00', '17:45:00');
```

## Mantenimiento

### Backup Manual

```bash
bash scripts/backup.sh
```

Genera: `backups/productividad_YYYYMMDD_HHMMSS.sql.gz`

### Backup Automático (Cron)

Editar crontab:
```bash
crontab -e
```

Agregar línea (backup diario 2 AM):
```bash
0 2 * * * /Users/mario/Proyectos/monitoreoDB/scripts/backup.sh
```

### Limpiar Datos Antiguos (>90 días)

```sql
DELETE FROM accesos_diarios 
WHERE fecha < CURRENT_DATE - INTERVAL '90 days';
```

### Regenerar KPI Mensual

```sql
TRUNCATE TABLE kpi_mensual CASCADE;

INSERT INTO kpi_mensual 
SELECT 
  ROW_NUMBER() OVER (),
  d.departamento_id,
  EXTRACT(MONTH FROM ad.fecha),
  EXTRACT(YEAR FROM ad.fecha),
  COUNT(DISTINCT ad.empleado_id),
  SUM(CASE WHEN ap.categoria_id = 1 THEN ad.minutos_totales ELSE 0 END),
  SUM(CASE WHEN ap.categoria_id IN (2, 3) THEN ad.minutos_totales ELSE 0 END),
  ROUND(100.0 * SUM(CASE WHEN ap.categoria_id = 1 THEN ad.minutos_totales ELSE 0 END) / 
        NULLIF(SUM(ad.minutos_totales), 0), 2),
  COUNT(al.alerta_id),
  NOW()
FROM departamentos d
LEFT JOIN empleados e ON d.departamento_id = e.departamento_id
LEFT JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
LEFT JOIN aplicaciones ap ON ad.app_id = ap.app_id
LEFT JOIN alertas al ON e.empleado_id = al.empleado_id
GROUP BY d.departamento_id, EXTRACT(MONTH FROM ad.fecha), EXTRACT(YEAR FROM ad.fecha);
```

### Ver Tabla de Auditoria

```sql
SELECT 
  usuario,
  tabla,
  accion,
  fecha_cambio,
  valor_anterior,
  valor_nuevo
FROM auditoria_cambios
ORDER BY fecha_cambio DESC
LIMIT 50;
```

## Indexes

Creados automáticamente en schema para optimizar:
- `accesos_diarios` (empleado_id, fecha, app_id)
- `alertas` (empleado_id, resuelta)
- `auditoria_cambios` (fecha_cambio)
- `dispositivos` (empleado_id)

## Permisos

### Usuario API (api_user)

```sql
GRANT CONNECT ON DATABASE productividad_corporativa TO api_user;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO api_user;
GRANT SELECT, INSERT, UPDATE ON 
  accesos_diarios, alertas, empleados, dispositivos 
  TO api_user;
```

### Crear Nuevo Usuario

```sql
CREATE USER reporte WITH PASSWORD 'reporte_pass';
GRANT CONNECT ON DATABASE productividad_corporativa TO reporte;
GRANT USAGE ON SCHEMA public TO reporte;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporte;
```

## Troubleshooting

### PostgreSQL No Conecta

```bash
# Ver logs
docker logs productividad_pg

# Verificar puerto
lsof -i :5432

# Reiniciar contenedor
docker-compose -f docker/docker-compose-postgrest.yml restart postgres
```

### Error: "role api_user does not exist"

Schema no cargó correctamente. Ejecutar:
```bash
bash scripts/init.sh
```

### Espacio en Disco Bajo

Ver tamaño base de datos:
```sql
SELECT pg_size_pretty(pg_database_size('productividad_corporativa'));
```

Limpiar datos viejos:
```sql
DELETE FROM accesos_diarios WHERE fecha < CURRENT_DATE - INTERVAL '180 days';
VACUUM ANALYZE;
```

### Queries Lentas

Ver índices:
```sql
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
```

Analizar tabla:
```sql
ANALYZE accesos_diarios;
```

## Enums Disponibles

```sql
-- Estados empleado
CREATE TYPE estado_empleado AS ENUM ('Activo', 'Inactivo', 'Licencia', 'Suspendido');

-- Categorías app
CREATE TYPE categoria_enum AS ENUM ('Productiva', 'Distracción', 'Peligrosa');

-- Tipos dispositivo
CREATE TYPE tipo_dispositivo AS ENUM ('Laptop', 'Desktop', 'Tablet', 'Smartphone');

-- Tipos alerta
CREATE TYPE tipo_alerta AS ENUM ('Exceso Distracción', 'Acceso Peligrosa', 'Inactividad Sospechosa', 'Anomalía Horaria');

-- Acciones auditoria
CREATE TYPE accion_auditoria AS ENUM ('INSERT', 'UPDATE', 'DELETE');
```

## Estadísticas

Ver tamaño tablas:
```sql
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS tamaño
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

Filas por tabla:
```sql
SELECT 
  tablename,
  n_live_tup AS filas
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

## Restaurar Backup

```bash
# Descomprimir si es .gz
gunzip backups/productividad_20260518_021530.sql.gz

# Restaurar
PGPASSWORD=postgres_pass psql \
  -h localhost \
  -U postgres \
  -d productividad_corporativa \
  < backups/productividad_20260518_021530.sql
```

## Documentación Relacionada

- `PROYECTO.md` - Visión general
- `README_POSTGREST.md` - API REST
- `sql/schema_postgres.sql` - DDL completo
- `sql/cargar_datos_postgres.sql` - Datos iniciales

## Contacto

Problemas: Verificar logs con `docker logs productividad_pg`
