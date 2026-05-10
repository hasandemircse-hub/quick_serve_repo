#!/usr/bin/env bash
# Cloud VM: CLOUD_JWT_SECRET en az 32 karakter değilse üretir, .env.cloud yazar, backend'i yeniden başlatır.
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-$HOME/quick_serve}"
ENV_FILE="${ENV_FILE:-$COMPOSE_DIR/.env.cloud}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.cloud.yml}"
MIN_LEN=32

usage() {
  echo "Kullanım: $0 [--force]"
  echo "  --force   Mevcut secret yeterli olsa bile yeni secret üret"
  echo ""
  echo "Ortam: COMPOSE_DIR, ENV_FILE, COMPOSE_FILE"
  exit 1
}

FORCE=0
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; fi
if [[ "${1:-}" == "--force" ]]; then FORCE=1; shift; fi
[[ "${1:-}" == "" ]] || usage

command -v openssl >/dev/null 2>&1 || { echo "openssl gerekli."; exit 1; }

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Hata: $ENV_FILE bulunamadı."
  exit 1
fi

current=""
if grep -q '^CLOUD_JWT_SECRET=' "$ENV_FILE"; then
  current="$(grep '^CLOUD_JWT_SECRET=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
fi
len=${#current}

if [[ $FORCE -eq 0 && $len -ge $MIN_LEN ]]; then
  echo "CLOUD_JWT_SECRET zaten yeterli uzunlukta (${len} >= ${MIN_LEN}). Değişiklik yok."
  echo "Yenilemek için: $0 --force"
  exit 0
fi

# 32 byte → 64 hex karakter (HS256 için güvenli)
NEW_SECRET="$(openssl rand -hex 32)"
tmp="${ENV_FILE}.tmp.$$"
cp -a "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"

if grep -q '^CLOUD_JWT_SECRET=' "$ENV_FILE"; then
  awk -v s="$NEW_SECRET" '
    BEGIN { done=0 }
    /^CLOUD_JWT_SECRET=/ { print "CLOUD_JWT_SECRET=" s; done=1; next }
    { print }
    END { if (!done) print "CLOUD_JWT_SECRET=" s }
  ' "$ENV_FILE" >"$tmp"
else
  cat "$ENV_FILE" >"$tmp"
  echo "CLOUD_JWT_SECRET=${NEW_SECRET}" >>"$tmp"
fi

mv "$tmp" "$ENV_FILE"
echo "CLOUD_JWT_SECRET güncellendi (${#NEW_SECRET} karakter). Yedek: ${ENV_FILE}.bak.*"

cd "$COMPOSE_DIR"
sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d cloud-backend
echo "cloud-backend yeniden başlatıldı. Birkaç saniye sonra login dene."
