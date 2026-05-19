# 🚀Inicio Rápido - Paso a Paso

Levanta el sistema de monitoreo en 5 minutos.

## Paso 1: Abrir Docker Desktop

1. Abre **Docker Desktop** desde Applications
2. Espera 2-3 minutos hasta que esté totalmente iniciado

## Paso 2: Abre Terminal

```bash
cd /donde-tengas-el-proyecto/monitoreoDB
```

## Paso 3: Ejecuta Inicialización

```bash
bash scripts/init.sh
```

Espera mensajes:
- `⏳ Esperando PostgreSQL...`
- `✅ PostgreSQL listo`
- `📋 Cargando schema...`
- `📊 Cargando datos iniciales...`
- `✅ ¡BD LISTA!`

## Paso 4: Verifica que Todo Funciona

En **otra terminal** (nueva ventana):

### Probar API
```bash
curl http://localhost:3000/empleados | jq .
```

Debe mostrar lista de empleados en JSON.

### Acceder a pgAdmin
- URL: http://localhost:5050
- Email: `admin@example.com`
- Contraseña: `admin`

### Acceder a API
- URL: http://localhost:3000
- Muestra Swagger (documentación)

## Listo ✅

Sistema corriendo:
- **API REST:** http://localhost:3000
- **pgAdmin UI:** http://localhost:5050
- **PostgreSQL:** localhost:5432

## Uso

### Ver Consultas Interactivas

```bash
bash scripts/queries.sh
```

Menú con opciones para ver:
- Empleados
- Departamentos
- KPI mensual
- Consumo empleados
- Top apps
- Y más...

### Conectar Directo a Base de Datos

```bash
PGPASSWORD=postgres_pass psql \
  -h localhost \
  -U postgres \
  -d productividad_corporativa
```

Luego escribe queries SQL.

## Detener Sistema

```bash
bash scripts/stop.sh
```

Preguntas:
- ¿Eliminar volúmenes de datos? → `n` (preserva datos)
- ¿Limpiar archivos de log? → `s` o `n`

## Reiniciar

Después de detener:

```bash
docker-compose -f docker/docker-compose-postgrest.yml up -d
```

## Problemas

### Docker no inicia
→ Abre Docker Desktop y espera

### Puerto 3000 ocupado
```bash
lsof -i :3000
kill -9 <PID>
```

### PostgreSQL no conecta
```bash
docker logs productividad_pg
```

### Reiniciar todo desde cero
```bash
bash scripts/stop.sh
# Responder SÍ a eliminar volúmenes
bash scripts/init.sh
```

---

**¿Necesitas más?** Ver `README_POSTGRES.md` para queries avanzadas.
