#!/usr/bin/env bash
# VM üzerinde (repo kökünden): git pull sonrası cloud backend imajı + cloud-frontend web
# tek komutla günceller. Gereksinim: Docker (+ Compose v2), internet (Flutter base image).
#
# Kullanım:
#   cd /path/to/quick_serve   # docker-compose.cloud.yml ve .env.cloud burada olmalı
#   git pull
#   ./scripts/update_cloud_on_vm.sh http://192.168.139.157
#
# veya:
#   export QUICKSERVE_PUBLIC_BASE=http://192.168.139.157
#   ./scripts/update_cloud_on_vm.sh
#
# İsteğe bağlı:
#   FLUTTER_DOCKER_IMAGE=ghcr.io/cirruslabs/flutter:stable
#   QUICKSERVE_EDGE_API_URL=http://192.168.139.157:8081/api   # farklı edge API ise
#   QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE=true|false  (VM'deki .env.cloud içine otomatik yazılır)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f docker-compose.cloud.yml ]]; then
  echo "Hata: docker-compose.cloud.yml bulunamadı (cwd: $ROOT)" >&2
  exit 1
fi

ENV_FILE="${CLOUD_ENV_FILE:-$ROOT/.env.cloud}"
COMPOSE_FILE="${CLOUD_COMPOSE_FILE:-$ROOT/docker-compose.cloud.yml}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Hata: .env.cloud bulunamadı: $ENV_FILE" >&2
  exit 1
fi

#
# Opsiyonel: script çalıştırıldığı ortamda QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE verilmişse
# VM'deki .env.cloud içinde aynı değeri tutmak için dosyayı güncelle.
#
if [[ -n "${QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE:-}" ]]; then
  tmp="${ENV_FILE}.tmp.$$"
  awk -v key="QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE" -v val="$QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE" '
    BEGIN { done=0 }
    $0 ~ ("^" key "=") { print key "=" val; done=1; next }
    { print }
    END { if (!done) print key "=" val }
  ' "$ENV_FILE" >"$tmp"
  mv "$tmp" "$ENV_FILE"
fi

PUBLIC_BASE="${1:-${QUICKSERVE_PUBLIC_BASE:-}}"
if [[ -z "$PUBLIC_BASE" ]]; then
  echo "Kullanım: $0 <http(s)://sunucu-adresi>" >&2
  echo "  örn: $0 http://192.168.139.157" >&2
  echo "veya QUICKSERVE_PUBLIC_BASE ortam değişkenini ayarlayın." >&2
  exit 1
fi
PUBLIC_BASE="${PUBLIC_BASE%/}"

CLOUD_API_URL="${QUICKSERVE_CLOUD_API_URL:-$PUBLIC_BASE/api}"
EDGE_API_URL="${QUICKSERVE_EDGE_API_URL:-$CLOUD_API_URL}"
WEB_ADMIN_URL="${QUICKSERVE_WEB_ADMIN_URL:-$PUBLIC_BASE/auth/admin}"

# docker-compose.yml ile aynı imaj adı (yerelde build edilince registry pull gerekmez)
BACKEND_IMAGE="${QUICKSERVE_CLOUD_BACKEND_IMAGE:-${QUICKSERVE_BACKEND_IMAGE:-quickserve-cloud-backend:local}}"
FLUTTER_IMAGE="${FLUTTER_DOCKER_IMAGE:-ghcr.io/cirruslabs/flutter:stable}"
FLUTTER_VOLUME_NAME="${QUICKSERVE_FLUTTER_WEB_VOLUME:-quickserve_flutter_web}"

echo "==> Public base: $PUBLIC_BASE"
echo "==> CLOUD_API_URL=$CLOUD_API_URL"
echo "==> Backend image: $BACKEND_IMAGE"
echo "==> Flutter image: $FLUTTER_IMAGE"

echo "==> [1/3] Docker: cloud-backend imajı..."
docker build -t "$BACKEND_IMAGE" -f "$ROOT/apps/cloud-backend/Dockerfile" "$ROOT/apps/cloud-backend"

echo "==> [2/3] Flutter web (cloud-frontend, konteyner içinde)..."
docker run --rm \
  -v "$ROOT:/work:rw" \
  -w /work/apps/cloud-frontend \
  -e PUB_CACHE="${PUB_CACHE:-/work/.pub-cache-docker}" \
  -e BUILD_API_URL="$CLOUD_API_URL" \
  -e BUILD_CLOUD_API_URL="$CLOUD_API_URL" \
  -e BUILD_EDGE_API_URL="$EDGE_API_URL" \
  -e BUILD_WEB_ADMIN_URL="$WEB_ADMIN_URL" \
  "$FLUTTER_IMAGE" \
  bash -lc 'set -euo pipefail
mkdir -p "$PUB_CACHE"
flutter pub get
flutter build web --release \
  --dart-define=API_URL="$BUILD_API_URL" \
  --dart-define=CLOUD_API_URL="$BUILD_CLOUD_API_URL" \
  --dart-define=EDGE_API_URL="$BUILD_EDGE_API_URL" \
  --dart-define=WEB_ADMIN_URL="$BUILD_WEB_ADMIN_URL"'

WEB_OUT="$ROOT/apps/cloud-frontend/build/web"
if [[ ! -f "$WEB_OUT/index.html" ]]; then
  echo "Hata: Flutter çıktısı yok: $WEB_OUT/index.html" >&2
  exit 1
fi

echo "==> [3/3] Statik dosyaları Docker volume'a kopyala ve compose yenile..."
docker run --rm \
  -v "$WEB_OUT:/src:ro" \
  -v "${FLUTTER_VOLUME_NAME}:/dst" \
  alpine sh -c "rm -rf /dst/* /dst/.[!.]* 2>/dev/null || true; cp -a /src/. /dst/"

echo "==> Docker compose (cloud): up -d (env-file=$ENV_FILE)"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --no-build --force-recreate cloud-backend cloud-nginx

echo "==> Bitti: $PUBLIC_BASE (gerekirse tarayıcıda sert yenile: Ctrl+Shift+R)"
