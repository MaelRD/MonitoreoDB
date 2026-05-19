#!/bin/bash

# ============================================
# Script Backup BD
# ============================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

source .env

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/productividad_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

echo "💾 Realizando backup..."

PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
  -h localhost \
  -U $POSTGRES_USER \
  -d $POSTGRES_DB \
  --verbose \
  --file="$BACKUP_FILE"

echo "✅ Backup completado: $BACKUP_FILE"

# Comprimir si existe gzip
if command -v gzip &> /dev/null; then
  gzip "$BACKUP_FILE"
  echo "📦 Comprimido: ${BACKUP_FILE}.gz"
fi

# Limpiar backups viejos (>30 días)
echo "🧹 Limpiando backups viejos..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.sql" -mtime +30 -delete

echo "✅ Backup finalizado"
