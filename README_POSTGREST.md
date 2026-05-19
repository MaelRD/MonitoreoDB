# BD Análisis Productividad + PostgREST API

## Estructura

- `schema_postgres.sql` - Tablas PostgreSQL + enums + permisos
- `cargar_datos_postgres.sql` - Datos ejemplo + vistas + alertas
- `docker-compose-postgrest.yml` - PostgreSQL + PostgREST + pgAdmin

## Iniciar Servicios

```bash
docker-compose -f docker-compose-postgrest.yml up -d
```

Esperar a que PostgreSQL esté listo (~15-30s):
```bash
docker logs productividad_pg | grep "database system is ready"
```

## Acceso

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **PostgREST API** | http://localhost:3000 | (sin auth) |
| **pgAdmin** | http://localhost:5050 | admin@example.com / admin |
| **PostgreSQL** | localhost:5432 | postgres / postgres_pass |

## Cargar Datos Iniciales

```bash
PGPASSWORD=postgres_pass psql -h localhost -U postgres -d productividad_corporativa \
  -f cargar_datos_postgres.sql
```

O desde pgAdmin:
1. Ir a http://localhost:5050
2. Register → Quick Link (localhost:5432, postgres/postgres_pass)
3. Crear BD productividad_corporativa
4. Tools → Query Tool → Pegar schema_postgres.sql y cargar_datos_postgres.sql

## Usar PostgREST API

PostgREST genera automáticamente endpoints REST desde tablas.

### Endpoints Principales

```bash
# Listar empleados
curl http://localhost:3000/empleados

# Listar departamentos
curl http://localhost:3000/departamentos

# Listar accesos diarios
curl http://localhost:3000/accesos_diarios

# Listar aplicaciones
curl http://localhost:3000/aplicaciones

# Listar alertas
curl http://localhost:3000/alertas

# Listar categorías
curl http://localhost:3000/categorias_app
```

### Filtros

```bash
# Empleados activos
curl "http://localhost:3000/empleados?estado=eq.Activo"

# Empleados de departamento 1
curl "http://localhost:3000/empleados?departamento_id=eq.1"

# Accesos de empleado 1
curl "http://localhost:3000/accesos_diarios?empleado_id=eq.1"

# Alertas no resueltas
curl "http://localhost:3000/alertas?resuelta=eq.false"

# Apps de categoría "Distracción"
curl "http://localhost:3000/aplicaciones?categoria_id=eq.2"
```

### Ordenamiento y Límite

```bash
# Top 10 accesos más recientes
curl "http://localhost:3000/accesos_diarios?order=created_at.desc&limit=10"

# Primeros 5 empleados, ordenados por nombre
curl "http://localhost:3000/empleados?order=nombre.asc&limit=5"
```

### Seleccionar Columnas

```bash
# Solo nombre y email
curl "http://localhost:3000/empleados?select=nombre,email"

# Empleados con departamento
curl "http://localhost:3000/empleados?select=nombre,email,departamentos(nombre)"
```

### Agregar Datos (POST)

```bash
# Crear nuevo acceso
curl -X POST http://localhost:3000/accesos_diarios \
  -H "Content-Type: application/json" \
  -d '{
    "empleado_id": 1,
    "app_id": 1,
    "fecha": "2026-05-18",
    "minutos_totales": 120,
    "numero_accesos": 5,
    "primer_acceso": "09:00:00",
    "ultimo_acceso": "11:00:00"
  }'
```

### Actualizar Datos (PATCH)

```bash
# Resolver alerta
curl -X PATCH "http://localhost:3000/alertas?alerta_id=eq.1" \
  -H "Content-Type: application/json" \
  -d '{"resuelta": true, "nota_resolucion": "Revisado por RH"}'
```

### Eliminar Datos (DELETE)

```bash
# Eliminar alerta
curl -X DELETE "http://localhost:3000/alertas?alerta_id=eq.1"
```

## Vistas Analíticas (PostgREST Compatible)

```bash
# KPI mes actual por departamento
curl "http://localhost:3000/v_kpi_mensual_actual"

# Consumo empleados mes actual
curl "http://localhost:3000/v_empleado_consumo"

# Top apps por categoría
curl "http://localhost:3000/v_top_apps_por_categoria"
```

## Queries Avanzadas (RPC en PostgreSQL)

Crear función para reportes:

```sql
CREATE OR REPLACE FUNCTION generar_reporte_departamento(dept_id INT)
RETURNS TABLE (
  departamento VARCHAR,
  productividad NUMERIC,
  distracciones INT,
  total_empleados INT
) AS $$
SELECT
  d.nombre,
  ROUND(SUM(CASE WHEN ca.nombre='Productiva' THEN ad.minutos_totales ELSE 0 END)::numeric /
        NULLIF(SUM(ad.minutos_totales), 0) * 100, 2),
  SUM(CASE WHEN ca.nombre='Distracción' THEN ad.minutos_totales ELSE 0 END),
  COUNT(DISTINCT e.empleado_id)
FROM departamentos d
JOIN empleados e ON d.departamento_id = e.departamento_id
LEFT JOIN accesos_diarios ad ON e.empleado_id = ad.empleado_id
LEFT JOIN aplicaciones a ON ad.app_id = a.app_id
LEFT JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE d.departamento_id = dept_id
GROUP BY d.nombre;
$$ LANGUAGE SQL;

GRANT EXECUTE ON FUNCTION generar_reporte_departamento(INT) TO api_user;
```

Luego llamar:
```bash
curl "http://localhost:3000/rpc/generar_reporte_departamento?dept_id=1"
```

## Conectar desde Aplicación

### JavaScript/Node

```javascript
const response = await fetch('http://localhost:3000/empleados?estado=eq.Activo');
const empleados = await response.json();
console.log(empleados);
```

### Python

```python
import requests

response = requests.get('http://localhost:3000/empleados?estado=eq.Activo')
empleados = response.json()
print(empleados)
```

### cURL Completo

```bash
# Con formato bonito
curl -s "http://localhost:3000/empleados?select=nombre,email,departamento_id&order=nombre.asc" | jq .
```

## Documentación API

PostgREST genera automáticamente OpenAPI:
```
http://localhost:3000/
```

Ver swagger UI en browser. Todos endpoints documentados.

## Optimizaciones PostgREST

Agregar a schema para mejor performance:

```sql
-- Índices para filtros frecuentes
CREATE INDEX idx_accesos_empleado_fecha ON accesos_diarios(empleado_id, fecha DESC);
CREATE INDEX idx_alertas_resueltas ON alertas(resuelta) WHERE resuelta = false;

-- RLS (Row Level Security) si necesitas multi-tenancy
ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
CREATE POLICY empleado_policy ON empleados
  FOR SELECT USING (true);  -- Ajustar según roles
```

## Detener Servicios

```bash
docker-compose -f docker-compose-postgrest.yml down
```

## Variables de Entorno (Producción)

Crear `.env`:
```
PGRST_DB_URI=postgresql://api_user:api_pass@postgres:5432/productividad_corporativa
PGRST_JWT_SECRET=your-secure-secret-key-here
PGRST_DB_ANON_ROLE=api_user
```

Editar docker-compose para usar `.env` instead hardcoded.

## Troubleshooting

```bash
# Ver logs PostgREST
docker logs postgrest_api

# Ver logs PostgreSQL
docker logs productividad_pg

# Conectar directo a BD
PGPASSWORD=postgres_pass psql -h localhost -U postgres -d productividad_corporativa
```
