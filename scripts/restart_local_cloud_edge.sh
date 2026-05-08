#!/usr/bin/env bash

set -euo pipefail

# Tek komutla cloud + edge stack'i yeniden başlatır.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

UP_ARGS=()
DOWN_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Kullanım: ./scripts/restart_local_cloud_edge.sh [--skip-smoke] [--no-nginx] [--volumes] [--remove-orphans] [--verbose]"
      echo "  --skip-smoke     : Start sonrası smoke test adımını atlar"
      echo "  --no-nginx       : Cloud stack'i nginx olmadan başlatır"
      echo "  --volumes        : Restart öncesi down aşamasında volume'leri siler"
      echo "  --remove-orphans : Restart öncesi down aşamasında yetim container'ları da kaldırır"
      echo "  --verbose        : up/down scriptlerine verbose geçirir"
      exit 0
      ;;
    --skip-smoke|--no-nginx)
      UP_ARGS+=("$arg")
      ;;
    --volumes|--remove-orphans)
      DOWN_ARGS+=("$arg")
      ;;
    --verbose)
      UP_ARGS+=("$arg")
      DOWN_ARGS+=("$arg")
      ;;
    *)
      echo "Bilinmeyen argüman: $arg"
      echo "Kullanım: ./scripts/restart_local_cloud_edge.sh [--skip-smoke] [--no-nginx] [--volumes] [--remove-orphans] [--verbose]"
      exit 1
      ;;
  esac
done

echo "Cloud + Edge stack durduruluyor..."
./scripts/down_local_cloud_edge.sh "${DOWN_ARGS[@]}"

echo "Cloud + Edge stack başlatılıyor..."
./scripts/up_local_cloud_edge.sh "${UP_ARGS[@]}"

echo "Restart tamamlandı."
