#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/cloud_db_restore.sh --file <backup.sql>

Options:
  --file <backup.sql>  SQL backup file path
  --help               Show help
EOF
}

ENV_FILE="${ENV_FILE:-.env.cloud}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.cloud.yml}"
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      shift
      BACKUP_FILE="${1:-}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift || true
done

if [[ -z "$BACKUP_FILE" ]]; then
  echo "ERROR: --file is required."
  usage
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found."
  exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Restoring from: $BACKUP_FILE"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T cloud-postgres sh -lc \
  'psql -U "${POSTGRES_USER:-quickserve}" "${POSTGRES_DB:-quickserve}"' < "$BACKUP_FILE"

echo "Restore completed."
