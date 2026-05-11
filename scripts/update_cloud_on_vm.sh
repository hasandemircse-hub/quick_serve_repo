#!/usr/bin/env bash
# VM üzerinde (repo kökünden): git pull sonrası cloud backend imajı + cloud-frontend web
# tek komutla günceller. Gereksinim: Docker (+ Compose v2), internet (Flutter base image).
#
# Kullanım:
#   cd /path/to/quick_serve   # docker-compose.yml ve .env burada olmalı
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

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f docker-compose.yml ]]; then
  echo "Hata: docker-compose.yml bulunamadı (cwd: $ROOT)" >&2
  exit 1
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
BACKEND_IMAGE="${QUICKSERVE_BACKEND_IMAGE:-ghcr.io/hasandemircse-hub/quick_serve/quickserve-backend:latest}"
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

ENV_FILE_ARGS=()
if [[ -f "$ROOT/.env" ]]; then
  ENV_FILE_ARGS=(--env-file "$ROOT/.env")
fi

docker compose "${ENV_FILE_ARGS[@]}" -f "$ROOT/docker-compose.yml" up -d

echo "==> Bitti: $PUBLIC_BASE (gerekirse tarayıcıda sert yenile: Ctrl+Shift+R)"
