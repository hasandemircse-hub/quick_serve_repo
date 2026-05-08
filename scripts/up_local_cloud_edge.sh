#!/usr/bin/env bash

set -euo pipefail

# Tek bilgisayarda cloud + edge stack'i aynı anda başlatır.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SKIP_SMOKE=false
NO_NGINX=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Kullanım: ./scripts/up_local_cloud_edge.sh [--skip-smoke] [--no-nginx] [--verbose]"
      echo "  --skip-smoke : Smoke test adımını atlar"
      echo "  --no-nginx   : Cloud stack'te nginx servisini başlatmaz"
      echo "  --verbose    : Script komutlarını ayrıntılı gösterir (set -x)"
      exit 0
      ;;
    --skip-smoke)
      SKIP_SMOKE=true
      ;;
    --no-nginx)
      NO_NGINX=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    *)
      echo "Bilinmeyen argüman: $arg"
      echo "Kullanım: ./scripts/up_local_cloud_edge.sh [--skip-smoke] [--no-nginx] [--verbose]"
      exit 1
      ;;
  esac
done

if [[ "$VERBOSE" == "true" ]]; then
  set -x
fi

check_port_free() {
  local port="$1"
  if lsof -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Uyarı: $port portu zaten kullanımda."
    lsof -iTCP:"$port" -sTCP:LISTEN
    return 1
  fi
  return 0
}

wait_health() {
  local name="$1"
  local url="$2"
  local timeout_seconds="${3:-60}"
  local elapsed=0
  local sleep_seconds=3

  echo "$name health bekleniyor: $url"
  while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
    local code
    code="$(curl -sS -m 5 -o /tmp/qs_health.txt -w '%{http_code}' "$url" || true)"
    if [[ "$code" == "200" ]]; then
      echo "$name health hazır."
      return 0
    fi
    sleep "$sleep_seconds"
    elapsed=$((elapsed + sleep_seconds))
  done

  echo "Hata: $name health timeout ($timeout_seconds sn)"
  return 1
}

print_failure_logs() {
  echo
  echo "Başlatma hatası. Son loglar:"
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml logs --tail=120 || true
  docker compose --env-file .env.edge -f docker-compose.edge.yml logs --tail=120 || true
}

trap 'print_failure_logs' ERR

if [[ ! -f ".env.cloud" ]]; then
  echo ".env.cloud yok, .env.cloud.example kopyalanıyor..."
  cp .env.cloud.example .env.cloud
  echo "Lütfen .env.cloud dosyasındaki secret alanlarını güncelle."
fi

if [[ ! -f ".env.edge" ]]; then
  echo ".env.edge yok, .env.edge.example kopyalanıyor..."
  cp .env.edge.example .env.edge
  echo "Lütfen .env.edge dosyasındaki edge bilgilerini güncelle."
fi

echo "Cloud/edge secret doğrulaması yapılıyor..."
./scripts/validate_env_secrets.sh --all

echo "Port kontrolleri yapılıyor..."
check_port_free 5432
check_port_free 8080
check_port_free 8081
check_port_free 80 || echo "Not: 80 doluysa cloud-nginx ayağa kalkamayabilir."

echo "Cloud stack başlatılıyor..."
if [[ "$NO_NGINX" == "true" ]]; then
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml up -d cloud-postgres cloud-backend
else
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml up -d
fi

echo "Edge stack başlatılıyor..."
docker compose --env-file .env.edge -f docker-compose.edge.yml up -d

wait_health "Cloud API" "http://localhost:8080/api/actuator/health" 90
wait_health "Edge API" "http://localhost:8081/api/actuator/health" 90

echo
echo "Servis durumları:"
docker compose --env-file .env.cloud -f docker-compose.cloud.yml ps
docker compose --env-file .env.edge -f docker-compose.edge.yml ps

echo
if [[ "$SKIP_SMOKE" == "true" ]]; then
  echo "Smoke test atlandı (--skip-smoke)."
else
  echo "Smoke test çalıştırılıyor..."
  ./scripts/smoke_cloud_edge.sh || true
fi

echo
echo "Tamamlandı. Gerekirse loglar:"
echo "  docker compose --env-file .env.cloud -f docker-compose.cloud.yml logs -f --tail=200"
echo "  docker compose --env-file .env.edge -f docker-compose.edge.yml logs -f --tail=200"
