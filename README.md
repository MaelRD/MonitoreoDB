# BD Análisis Productividad Corporativa

## Estructura

- `schema.sql` - Tablas y estructura base
- `cargar_datos.sql` - Datos de ejemplo + KPIs iniciales
- `docker-compose.yml` - Configuración MySQL + phpMyAdmin

## Iniciar BD

```bash
docker-compose up -d
```

Espera a que MySQL esté listo (verificar con `docker logs productividad_db`)

## Acceso

**phpMyAdmin**: http://localhost:8080
- Usuario: `usuario_bd`
- Contraseña: `password_segura`

**MySQL Directo**:
```bash
mysql -h 127.0.0.1 -u usuario_bd -p productividad_corporativa
# Contraseña: password_segura
```

## Cargar Datos Iniciales

```bash
mysql -h 127.0.0.1 -u usuario_bd -p productividad_corporativa < cargar_datos.sql
```

## Tablas Principales

| Tabla | Propósito |
|-------|-----------|
| `empleados` | Registro de empleados por departamento |
| `aplicaciones` | Catálogo de apps (dominio, categoría, riesgo) |
| `accesos_diarios` | Minutos consumidos por app/empleado/día |
| `kpi_mensual` | KPIs resumidos por departamento/mes |
| `alertas` | Anomalías detectadas automáticamente |
| `auditoria_cambios` | Registro de cambios en BD |

## Consultas Útiles

### KPI por Departamento (mes actual)
```sql
SELECT d.nombre, porcentaje_productivo, porcentaje_distraccion, app_top_1
FROM kpi_mensual k
JOIN departamentos d ON k.departamento_id = d.departamento_id
WHERE MONTH(k.mes) = MONTH(CURDATE());
```

### Empleados con Baja Productividad
```sql
SELECT e.nombre, kpi.porcentaje_productivo, kpi.anomalia_detectada
FROM kpi_empleado_mensual kpi
JOIN empleados e ON kpi.empleado_id = e.empleado_id
WHERE kpi.porcentaje_productivo < 40
ORDER BY kpi.porcentaje_productivo ASC;
```

### Apps Distractoras Más Usadas
```sql
SELECT a.nombre_app, SUM(ad.minutos_totales) as minutos
FROM accesos_diarios ad
JOIN aplicaciones a ON ad.app_id = a.app_id
JOIN categorias_app ca ON a.categoria_id = ca.categoria_id
WHERE ca.nombre = 'Distracción'
GROUP BY a.app_id
ORDER BY minutos DESC;
```

## Detener BD

```bash
docker-compose down
```

## Restaurar Datos (si necesario)

```bash
docker exec productividad_db mysql -u usuario_bd -p password_segura productividad_corporativa < cargar_datos.sql
```
