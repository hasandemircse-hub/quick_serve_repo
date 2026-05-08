#!/usr/bin/env bash

set -euo pipefail

# Tek bilgisayarda cloud + edge stack'i durdurur.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

REMOVE_VOLUMES=false
REMOVE_ORPHANS=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Kullanım: ./scripts/down_local_cloud_edge.sh [--volumes] [--remove-orphans] [--verbose]"
      echo "  --volumes        : Compose volume'lerini de siler"
      echo "  --remove-orphans : Yetim container'ları da kaldırır"
      echo "  --verbose        : Script komutlarını ayrıntılı gösterir (set -x)"
      exit 0
      ;;
    --volumes)
      REMOVE_VOLUMES=true
      ;;
    --remove-orphans)
      REMOVE_ORPHANS=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    *)
      echo "Bilinmeyen argüman: $arg"
      echo "Kullanım: ./scripts/down_local_cloud_edge.sh [--volumes] [--remove-orphans] [--verbose]"
      exit 1
      ;;
  esac
done

if [[ "$VERBOSE" == "true" ]]; then
  set -x
fi

compose_down_args=()
if [[ "$REMOVE_VOLUMES" == "true" ]]; then
  compose_down_args+=(--volumes)
fi
if [[ "$REMOVE_ORPHANS" == "true" ]]; then
  compose_down_args+=(--remove-orphans)
fi

if [[ -f ".env.cloud" ]]; then
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml down "${compose_down_args[@]}"
else
  docker compose -f docker-compose.cloud.yml down "${compose_down_args[@]}"
fi

if [[ -f ".env.edge" ]]; then
  docker compose --env-file .env.edge -f docker-compose.edge.yml down "${compose_down_args[@]}"
else
  docker compose -f docker-compose.edge.yml down "${compose_down_args[@]}"
fi

echo "Cloud + Edge stack durduruldu."
