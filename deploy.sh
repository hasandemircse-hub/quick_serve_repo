#!/bin/bash
# deploy.sh — Docker ve GitHub bağımsız, local'den direkt sunucuya deploy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================"
echo " QuickServe - Local Deploy Script"
echo "======================================"

# ─── Konfigürasyon ────────────────────────────────────────────────────────────
SERVER_USER="${DEPLOY_USER:-ubuntu}"
SERVER_HOST="${DEPLOY_HOST:?DEPLOY_HOST env variable is required}"
SERVER_PATH="${DEPLOY_PATH:-/opt/quickserve}"
API_URL="${API_URL:-http://$SERVER_HOST/api}"
BACKUP_COUNT=2

# ─── 1. Backend Build ─────────────────────────────────────────────────────────
echo "[1/6] Building backend (Maven)..."
cd "$SCRIPT_DIR/backend"
./mvnw clean package -DskipTests -q
cd "$SCRIPT_DIR"

# ─── 2. Flutter Web Build ─────────────────────────────────────────────────────
echo "[2/6] Building Flutter Web (API_URL=$API_URL)..."
cd "$SCRIPT_DIR/frontend_flutter"
flutter build web --dart-define=API_URL="$API_URL" --release -q
cd "$SCRIPT_DIR"

# ─── 3. Docker image ──────────────────────────────────────────────────────────
IMAGE_TAG="quickserve-backend:$(date +%Y%m%d-%H%M%S)"
IMAGE_LATEST="quickserve-backend:latest"

echo "[3/6] Building Docker image: $IMAGE_TAG"
docker build -t "$IMAGE_TAG" -t "$IMAGE_LATEST" ./backend

# ─── 4. Save image ────────────────────────────────────────────────────────────
echo "[4/6] Saving Docker image..."
TARFILE="/tmp/quickserve-backend-$(date +%Y%m%d-%H%M%S).tar"
docker save "$IMAGE_LATEST" -o "$TARFILE"

# ─── 5. Transfer to server ────────────────────────────────────────────────────
echo "[5/6] Transferring to $SERVER_HOST..."
ssh "$SERVER_USER@$SERVER_HOST" "mkdir -p $SERVER_PATH/flutter_web"
scp "$TARFILE" "$SERVER_USER@$SERVER_HOST:/tmp/"
scp "$SCRIPT_DIR/docker-compose.yml" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/"
scp "$SCRIPT_DIR/nginx.conf" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/"
# Flutter web dosyalarını kopyala
rsync -az --delete \
  "$SCRIPT_DIR/frontend_flutter/build/web/" \
  "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/flutter_web/"

# ─── 6. Deploy on server ──────────────────────────────────────────────────────
echo "[6/6] Deploying on server..."
TARFILE_NAME=$(basename "$TARFILE")

ssh "$SERVER_USER@$SERVER_HOST" bash << EOF
  set -e
  cd $SERVER_PATH

  # Eski yedekleri yönet (son $BACKUP_COUNT adet tut)
  ls -t /tmp/quickserve-backend-*.tar 2>/dev/null | tail -n +$((BACKUP_COUNT+1)) | xargs -r rm -f

  # Yeni image'ı yükle
  docker load -i /tmp/$TARFILE_NAME
  echo "Image loaded."

  # .env kontrolü
  if [ ! -f .env ]; then
    echo "ERROR: .env file not found at $SERVER_PATH/.env"
    echo "Önce .env dosyasını oluşturun: cp .env.example .env && nano .env"
    exit 1
  fi

  # Flutter web dosyalarını volume'a kopyala
  docker run --rm \
    -v $SERVER_PATH/flutter_web:/src:ro \
    -v quickserve_flutter_web:/dst \
    alpine sh -c "cp -r /src/. /dst/"

  # Servisleri yeniden başlat
  docker compose pull postgres || true
  docker compose up -d --no-deps backend nginx
  echo "Containers restarted."

  # Health check
  sleep 10
  if curl -sf http://localhost/api/actuator/health > /dev/null; then
    echo "Health check PASSED."
  else
    echo "Health check FAILED. Check logs: docker compose logs"
    exit 1
  fi
EOF

rm -f "$TARFILE"
echo ""
echo "Deploy successful! $(date)"
echo "Uygulama: http://$SERVER_HOST"
