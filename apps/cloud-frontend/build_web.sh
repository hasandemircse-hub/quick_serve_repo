#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/cloud-frontend"
OUT_DIR="$APP_DIR/build/web"

CLOUD_API_URL="${CLOUD_API_URL:-http://localhost:8080/api}"
WEB_ADMIN_URL="${WEB_ADMIN_URL:-http://localhost:8080/auth/admin}"

echo "Building cloud-frontend artifact..."
echo "CLOUD_API_URL=$CLOUD_API_URL"
echo "WEB_ADMIN_URL=$WEB_ADMIN_URL"

mkdir -p "$OUT_DIR"
pushd "$APP_DIR" >/dev/null
flutter pub get
flutter build web \
  --dart-define=API_URL="$CLOUD_API_URL" \
  --dart-define=CLOUD_API_URL="$CLOUD_API_URL" \
  --dart-define=WEB_ADMIN_URL="$WEB_ADMIN_URL" \
  --release \
  --web-renderer canvaskit
popd >/dev/null

echo "cloud-frontend build ready: $OUT_DIR"
