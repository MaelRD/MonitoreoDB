#!/bin/bash

# ============================================
# Script de Inicialización BD
# ============================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🚀 Inicializando BD Análisis Productividad..."

# Cargar variables de entorno
if [ ! -f .env ]; then
  echo "❌ .env no encontrado. Copia .env.example o crea uno."
  exit 1
fi

source .env

# Verificar Docker
if ! command -v docker &> /dev/null; then
  echo "❌ Docker no instalado."
  exit 1
fi

echo "📦 Levantando servicios..."
docker-compose -f docker/docker-compose-postgrest.yml up -d

echo "⏳ Esperando PostgreSQL..."
sleep 10

# Verificar conexión
echo "🔍 Verificando conexión..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d postgres -c "\q" 2>/dev/null; do
  echo "⏳ Esperando PostgreSQL..."
  sleep 2
done

echo "✅ PostgreSQL listo"

# Cargar schema
echo "📋 Cargando schema..."
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -f sql/schema_postgres.sql

# Cargar datos iniciales
echo "📊 Cargando datos iniciales..."
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB -f sql/cargar_datos_postgres.sql

echo ""
echo "✅ ¡BD LISTA!"
echo ""
echo "📍 Acceso:"
echo "   PostgREST API: http://localhost:$POSTGREST_PORT"
echo "   pgAdmin: http://localhost:$PGADMIN_PORT"
echo "   PostgreSQL: localhost:$POSTGRES_PORT"
echo ""
echo "👤 Credenciales:"
echo "   pgAdmin: $PGADMIN_DEFAULT_EMAIL / $PGADMIN_DEFAULT_PASSWORD"
echo "   PostgreSQL: $POSTGRES_USER / $POSTGRES_PASSWORD"
echo "   API User: $API_USER / $API_PASSWORD"
echo ""
echo "🧪 Prueba API:"
echo "   curl http://localhost:$POSTGREST_PORT/empleados | jq ."
