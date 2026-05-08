#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ENV_FILE:-.env.cloud}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.cloud.yml}"
BACKUP_DIR="${BACKUP_DIR:-backups/cloud-db}"

mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$BACKUP_DIR/db-$TS.sql"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found."
  exit 1
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T cloud-postgres sh -lc \
  'pg_dump -U "${POSTGRES_USER:-quickserve}" "${POSTGRES_DB:-quickserve}"' > "$OUT_FILE"

echo "Backup created: $OUT_FILE"

# Keep last 10 backups
ls -1t "$BACKUP_DIR"/db-*.sql 2>/dev/null | awk 'NR>10' | xargs -r rm -f
