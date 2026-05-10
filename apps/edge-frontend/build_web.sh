#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/edge-frontend"
OUT_DIR="$APP_DIR/build/web"

EDGE_API_URL="${EDGE_API_URL:-http://localhost:8081/api}"
CLOUD_API_URL="${CLOUD_API_URL:-http://localhost:8080/api}"

echo "Building edge-frontend artifact..."
echo "EDGE_API_URL=$EDGE_API_URL"
echo "CLOUD_API_URL=$CLOUD_API_URL"

mkdir -p "$OUT_DIR"
pushd "$APP_DIR" >/dev/null
flutter pub get
flutter build web \
  --dart-define=API_URL="$EDGE_API_URL" \
  --dart-define=EDGE_API_URL="$EDGE_API_URL" \
  --dart-define=CLOUD_API_URL="$CLOUD_API_URL" \
  --release
popd >/dev/null

echo "edge-frontend build ready: $OUT_DIR"
