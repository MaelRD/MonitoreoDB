# 📊 Monitoreo BD - Análisis Productividad Corporativa

Sistema completo de análisis de productividad corporativa con PostgreSQL + PostgREST API.

## Estructura Proyecto

```
monitoreoDB/
├── sql/                          # Archivos SQL
│   ├── schema_postgres.sql       # Tablas + enums + permisos
│   ├── cargar_datos_postgres.sql # Datos ejemplo + vistas
│   ├── schema.sql                # MySQL (alternativo)
│   └── cargar_datos.sql          # MySQL datos
├── docker/                       # Docker Compose
│   ├── docker-compose-postgrest.yml  # PG + PostgREST (recomendado)
│   └── docker-compose.yml        # MySQL (alternativo)
├── scripts/                      # Utilidades
│   ├── init.sh                   # Inicializar BD
│   ├── backup.sh                 # Backup automático
│   ├── queries.sh                # Consultas interactivas
│   └── stop.sh                   # Detener servicios
├── logs/                         # Logs de aplicación
├── backups/                      # Backups de BD
├── 2026-05-12.txt                # Datos originales
├── 2026-05-13.txt                # Datos originales
├── .env                          # Variables de entorno
├── README_POSTGREST.md           # Docs API PostgREST
├── README.md                     # Docs MySQL
└── PROYECTO.md                   # Este archivo
```

## Quick Start

### 1. Inicializar (una sola vez)

```bash
cd /Users/mario/Proyectos/monitoreoDB

# Verificar .env está configurado
cat .env

# Ejecutar init (levanta servicios + carga datos)
bash scripts/init.sh
```

Espera mensaje: "✅ ¡BD LISTA!"

### 2. Acceder

| Componente | URL | Credencial |
|-----------|-----|-----------|
| **API REST** | http://localhost:3000 | (sin auth) |
| **pgAdmin UI** | http://localhost:5050 | admin@example.com / admin |
| **PostgreSQL** | localhost:5432 | postgres / postgres_pass |

### 3. Probar API

```bash
# Terminal - Empleados
curl -s http://localhost:3000/empleados | jq .

# O usar queries.sh
bash scripts/queries.sh
```

## Base de Datos

### Tablas Principales

| Tabla | Propósito |
|-------|-----------|
| `empleados` | Registro empleados por departamento |
| `accesos_diarios` | Consumo tiempo por app/empleado/día |
| `aplicaciones` | Catálogo apps (dominio, categoría) |
| `departamentos` | Estructura organizacional |
| `alertas` | Anomalías detectadas |
| `dispositivos` | Registros MAC de empleados |

### Vistas Analíticas (READ-ONLY)

```
GET /v_kpi_mensual_actual        # KPI por departamento
GET /v_empleado_consumo          # Consumo por empleado
GET /v_top_apps_por_categoria    # Top apps por categoría
```

## API PostgREST

### Ejemplos

```bash
# GET - Listar todos
curl "http://localhost:3000/empleados"

# GET - Filtrar
curl "http://localhost:3000/empleados?estado=eq.Activo"
curl "http://localhost:3000/accesos_diarios?empleado_id=eq.1"

# GET - Seleccionar columnas
curl "http://localhost:3000/empleados?select=nombre,email"

# GET - Ordenar y limitar
curl "http://localhost:3000/empleados?order=nombre.asc&limit=10"

# POST - Crear
curl -X POST http://localhost:3000/accesos_diarios \
  -H "Content-Type: application/json" \
  -d '{"empleado_id":1,"app_id":1,"fecha":"2026-05-18",...}'

# PATCH - Actualizar
curl -X PATCH "http://localhost:3000/alertas?alerta_id=eq.1" \
  -H "Content-Type: application/json" \
  -d '{"resuelta":true}'

# DELETE - Eliminar
curl -X DELETE "http://localhost:3000/alertas?alerta_id=eq.1"
```

### Documentación API

Swagger automático:
```
http://localhost:3000/
```

## Scripts Disponibles

### init.sh
Levanta servicios y carga datos iniciales.

```bash
bash scripts/init.sh
```

### backup.sh
Crea backup SQL comprimido en `backups/`.

```bash
bash scripts/backup.sh
```

Automático cada noche (configurar cron):
```bash
0 2 * * * /Users/mario/Proyectos/monitoreoDB/scripts/backup.sh
```

### queries.sh
Menú interactivo con consultas predefinidas.

```bash
bash scripts/queries.sh
```

### stop.sh
Detiene servicios. Opcionalmente elimina volúmenes.

```bash
bash scripts/stop.sh
```

## Cargar Datos Reales

### Desde logs 2026-05-12 y 2026-05-13

Archivos ya están en carpeta raíz. Script en `sql/cargar_datos_postgres.sql` procesa automáticamente.

Para importar manualmente:

```bash
# Conectar a BD
PGPASSWORD=postgres_pass psql -h localhost -U postgres -d productividad_corporativa

# Ejecutar query para insertar desde archivo
\copy accesos_diarios(empleado_id, app_id, fecha, minutos_totales, numero_accesos, primer_acceso, ultimo_acceso) 
FROM '2026-05-13.txt' DELIMITER E'\t' CSV HEADER;
```

## Reportes Típicos

### KPI Mensual Departamento

```bash
curl -s "http://localhost:3000/v_kpi_mensual_actual?departamento_id=eq.1" | jq .
```

### Empleados Bajo Productivos (<40%)

```bash
curl -s "http://localhost:3000/v_empleado_consumo?porcentaje_productivo=lt.40" | jq .
```

### Apps Distractoras Top 10

```bash
curl -s "http://localhost:3000/v_top_apps_por_categoria?categoria=eq.Distracción&order=minutos_totales.desc&limit=10" | jq .
```

### Alertas No Resueltas

```bash
curl -s "http://localhost:3000/alertas?resuelta=eq.false&order=fecha_alerta.desc" | jq .
```

## Conectar desde Aplicación

### JavaScript/Node

```javascript
const fetch = require('node-fetch');

const resp = await fetch('http://localhost:3000/empleados?estado=eq.Activo');
const empleados = await resp.json();
console.log(empleados);
```

### Python

```python
import requests

resp = requests.get('http://localhost:3000/empleados?estado=eq.Activo')
empleados = resp.json()
print(empleados)
```

### cURL Bonito

```bash
curl -s "http://localhost:3000/empleados?select=nombre,email,departamento_id" | jq .
```

## Troubleshooting

### PostgreSQL no conecta

```bash
# Verificar logs
docker logs productividad_pg

# Reiniciar
docker-compose -f docker/docker-compose-postgrest.yml restart postgres
```

### PostgREST error 404

```bash
# Esperar a que PostgreSQL esté listo
docker logs postgrest_api

# Reiniciar PostgREST
docker-compose -f docker/docker-compose-postgrest.yml restart postgrest
```

### Conectar directo a BD

```bash
PGPASSWORD=postgres_pass psql \
  -h localhost \
  -U postgres \
  -d productividad_corporativa
```

## Mantenimiento

### Backup Diario Automático

Crear entrada cron:

```bash
crontab -e

# Agregar línea:
0 2 * * * /Users/mario/Proyectos/monitoreoDB/scripts/backup.sh
```

### Limpiar Datos Antiguos (90 días)

```bash
PGPASSWORD=postgres_pass psql \
  -h localhost \
  -U postgres \
  -d productividad_corporativa \
  -c "DELETE FROM accesos_diarios WHERE fecha < CURRENT_DATE - INTERVAL '90 days';"
```

### Regenerar KPI Mensual

```bash
bash scripts/init.sh  # Recarga datos y KPI
```

## Variables de Entorno

Editar `.env`:

```bash
# PostgreSQL
POSTGRES_PASSWORD=postgres_pass

# PostgREST JWT (cambiar en producción)
PGRST_JWT_SECRET=your-secure-secret-key

# Backups
BACKUP_SCHEDULE="0 2 * * *"
```

## Seguridad (Producción)

1. Cambiar contraseñas `.env`
2. Cambiar `PGRST_JWT_SECRET`
3. Activar SSL en PostgreSQL
4. Configurar RLS (Row Level Security)
5. Usar proxy/nginx frente a PostgREST
6. Limitar IP de conexión

Ver `README_POSTGREST.md` para detalles.

## Documentación Completa

- **README_POSTGREST.md** - API REST + ejemplos
- **README.md** - MySQL alternativo
- **sql/schema_postgres.sql** - Definición tablas

## Soporte

Problemas comunes:
- Docker no corre → Iniciar Docker Desktop
- Puerto ocupado → Cambiar en `.env` o `docker-compose.yml`
- Datos no aparecen → Verificar carga exitosa en `init.sh`

## Próximos Pasos

✅ BD lista  
⬜ Conectar aplicación cliente  
⬜ Dashboard visualización  
⬜ Alertas en tiempo real  
⬜ Reportes PDF automáticos  
