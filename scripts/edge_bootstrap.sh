#!/usr/bin/env bash
#
# Restoran PC: tek komutla edge-backend (docker-compose.edge.deploy.yml) kurulumu.
# Önkoşul: Docker + Compose plugin yüklü; bu repo (veya en azından compose dosyası + script) makinede.
#
# Örnek (repo kökünden):
#   ./scripts/edge_bootstrap.sh \
#     --cloud http://192.168.1.10/api \
#     --token "$ENROLLMENT_TOKEN" \
#     --restaurant-id 42
#
# İleride "git yok" senaryosu için: release paketinde bu script + yml + .env.edge.example
# barındırıp aynı argümanlarla çalıştırılabilir.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_REL="docker-compose.edge.deploy.yml"
COMPOSE="$ROOT/$COMPOSE_REL"
ENV_OUT="${EDGE_ENV_OUT:-$ROOT/.env.edge}"

CLOUD_BASE=""
TOKEN=""
REST_ID=""
NODE_ID=""
IMAGE_REPO="${EDGE_IMAGE_REPOSITORY:-ghcr.io/hasandemircse-hub/quick_serve/quickserve-edge-backend}"
IMAGE_TAG="${EDGE_IMAGE_TAG:-latest}"
BRIDGE_JWT=""

usage() {
  cat <<'EOF'
edge_bootstrap.sh — restoran PC’de edge-backend container kurulumu

Zorunlu argümanlar:
  --cloud <url>           EDGE_CLOUD_BASE_URL (örn. https://api.sirketin.com/api veya http://IP/api)
  --token <string>        EDGE_ENROLLMENT_TOKEN (cloud superadmin’in ürettiği kayıt token’ı)
  --restaurant-id <n>     EDGE_RESTAURANT_ID

İsteğe bağlı:
  --node-id <id>          EDGE_NODE_ID (verilmezse: quickserve-$(hostname | tr '[:upper:]' '[:lower:]') )
  --env-out <path>        .env.edge yazılacak dosya (varsayılan: repo kökü/.env.edge)

Ortam (isteğe bağlı):
  EDGE_IMAGE_REPOSITORY   (varsayılan: ghcr.io/.../quickserve-edge-backend)
  EDGE_IMAGE_TAG          (varsayılan: latest)
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cloud) CLOUD_BASE="${2:-}"; shift 2 ;;
    --token) TOKEN="${2:-}"; shift 2 ;;
    --restaurant-id) REST_ID="${2:-}"; shift 2 ;;
    --node-id) NODE_ID="${2:-}"; shift 2 ;;
    --env-out) ENV_OUT="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Bilinmeyen argüman: $1"; usage ;;
  esac
done

[[ -n "$CLOUD_BASE" && -n "$TOKEN" && -n "$REST_ID" ]] || usage
[[ -f "$COMPOSE" ]] || { echo "Bulunamadı: $COMPOSE"; exit 1; }

if [[ -z "$NODE_ID" ]]; then
  hn="$(hostname 2>/dev/null || echo local)"
  NODE_ID="quickserve-$(echo "$hn" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//;s/-*$//')"
  [[ -z "$NODE_ID" || "$NODE_ID" == "quickserve-" ]] && NODE_ID="quickserve-local"
fi

# Enrollment claim: edge node kaydı + bridge JWT üretimi (kullanıcı login bağımsız sync).
claim_payload="$(cat <<EOF
{"token":"$TOKEN","nodeName":"$NODE_ID","deviceType":"MINI_PC","localIp":"127.0.0.1"}
EOF
)"
claim_resp="$(curl -fsS -X POST "${CLOUD_BASE%/}/edge/enrollment/claim" \
  -H "Content-Type: application/json" \
  -d "$claim_payload")" || {
  echo "HATA: enrollment claim başarısız. CLOUD_BASE/TOKEN doğrula."
  exit 1
}

BRIDGE_JWT="$(python3 - <<'PY' "$claim_resp"
import json,sys
raw=sys.argv[1]
try:
    data=json.loads(raw)
    print(data.get("bridgeJwtToken",""))
except Exception:
    print("")
PY
)"

if [[ -z "$BRIDGE_JWT" ]]; then
  echo "HATA: claim yanıtında bridgeJwtToken yok."
  echo "Yanıt: $claim_resp"
  exit 1
fi

umask 077
cat >"$ENV_OUT" <<EOF
# edge_bootstrap.sh tarafından üretildi — $(date -Iseconds 2>/dev/null || date)
EDGE_NODE_ID=${NODE_ID}
EDGE_RESTAURANT_ID=${REST_ID}
EDGE_CLOUD_BASE_URL=${CLOUD_BASE}
EDGE_ENROLLMENT_TOKEN=${TOKEN}
EDGE_BRIDGE_JWT_TOKEN=${BRIDGE_JWT}
EDGE_SQLITE_PATH=/data/edge.db
EDGE_IMAGE_REPOSITORY=${IMAGE_REPO}
EDGE_IMAGE_TAG=${IMAGE_TAG}
EOF

echo "==> .env.edge yazıldı: $ENV_OUT"
echo "    EDGE_NODE_ID=$NODE_ID  EDGE_RESTAURANT_ID=$REST_ID"

cd "$ROOT"
docker compose -f "$COMPOSE_REL" --env-file "$ENV_OUT" pull
docker compose -f "$COMPOSE_REL" --env-file "$ENV_OUT" up -d

echo "==> Edge backend ayakta. Health: http://127.0.0.1:8081/api/actuator/health"
