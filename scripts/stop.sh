#!/bin/bash

# ============================================
# Script Stop/Cleanup
# ============================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

source .env

echo "🛑 Deteniendo servicios..."
docker-compose -f docker/docker-compose-postgrest.yml down

echo ""
read -p "¿Eliminar volúmenes de datos? (s/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
  echo "🗑️  Eliminando volúmenes..."
  docker-compose -f docker/docker-compose-postgrest.yml down -v
  echo "✅ Volúmenes eliminados"
else
  echo "✅ Servicios detenidos (datos preservados)"
fi

# Limpiar logs
read -p "¿Limpiar archivos de log? (s/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
  echo "🧹 Limpiando logs..."
  rm -f "$LOG_DIR"/*.log
  echo "✅ Logs eliminados"
fi

echo "✅ Stop completado"
