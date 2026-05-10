#!/usr/bin/env bash
# Cloud VM: Mac'te web build → tar/ssh (VM'de rsync gerekmez) → volume + nginx
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_HOST="${CLOUD_VM_HOST:-${1:-}}"
VM_USER="${CLOUD_VM_USER:-hasandemir}"
REMOTE="${VM_USER}@${VM_HOST}"
# İlk SSH/rsync: "Are you sure you want to continue" sorusu script'i kırmasın.
SSH_COMMON_OPTS="${CLOUD_VM_SSH_OPTS:--o StrictHostKeyChecking=accept-new}"

usage() {
  echo "Kullanım:"
  echo "  ./load_up <VM_IP>"
  echo "  CLOUD_VM_HOST=<VM_IP> ./scripts/cloud_vm_load_up.sh"
  echo ""
  echo "Opsiyonel ortam değişkenleri:"
  echo "  CLOUD_VM_USER          (varsayılan: hasandemir)"
  echo "  CLOUD_API_URL          (varsayılan: http://<VM_IP>/api)"
  echo "  CLOUD_VM_WEB_SUBDIR    (varsayılan: quick_serve/flutter_web → ~/quick_serve/flutter_web)"
  echo "  CLOUD_VM_COMPOSE_SUBDIR (varsayılan: quick_serve)"
  echo "  CLOUD_VM_ENV_FILE      (varsayılan: .env.cloud)"
  echo "  CLOUD_VM_COMPOSE_FILE  (varsayılan: docker-compose.cloud.yml)"
  echo "  CLOUD_VM_SSH_OPTS      (varsayılan: -o StrictHostKeyChecking=accept-new …)"
  echo "    Örnek port: CLOUD_VM_SSH_OPTS='-o StrictHostKeyChecking=accept-new -p 2222'"
  exit 1
}

[[ -n "$VM_HOST" ]] || usage
command -v flutter >/dev/null 2>&1 || {
  echo "flutter bulunamadı. PATH'e Flutter SDK ekleyin."
  exit 1
}
command -v tar >/dev/null 2>&1 || {
  echo "tar gerekli."
  exit 1
}

WEB_SUB="${CLOUD_VM_WEB_SUBDIR:-quick_serve/flutter_web}"
COMPOSE_SUB="${CLOUD_VM_COMPOSE_SUBDIR:-quick_serve}"
ENV_FILE="${CLOUD_VM_ENV_FILE:-.env.cloud}"
COMPOSE_FILE="${CLOUD_VM_COMPOSE_FILE:-docker-compose.cloud.yml}"

export CLOUD_API_URL="${CLOUD_API_URL:-http://${VM_HOST}/api}"
export WEB_ADMIN_URL="${WEB_ADMIN_URL:-http://${VM_HOST}/auth/admin}"

echo "==> Web build (CLOUD_API_URL=$CLOUD_API_URL)"
"$ROOT/apps/cloud-frontend/build_web.sh"

echo "==> tar+ssh → ${REMOTE}:~/${WEB_SUB}/"
ssh ${SSH_COMMON_OPTS} "$REMOTE" "rm -rf \"\$HOME/${WEB_SUB}\" && mkdir -p \"\$HOME/${WEB_SUB}\""
tar -C "$ROOT/apps/cloud-frontend/build/web" -cf - . \
  | ssh ${SSH_COMMON_OPTS} "$REMOTE" "tar -xf - -C \"\$HOME/${WEB_SUB}\""

echo "==> Volume + cloud-nginx (${ENV_FILE} / ${COMPOSE_FILE})"
ssh ${SSH_COMMON_OPTS} "$REMOTE" bash -s <<EOF
set -euo pipefail
sudo docker run --rm \\
  -v "\$HOME/${WEB_SUB}:/src:ro" \\
  -v quickserve_flutter_web:/dst \\
  alpine sh -c "cp -r /src/. /dst/"
cd "\$HOME/${COMPOSE_SUB}"
sudo docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" restart cloud-nginx
EOF

echo "==> Bitti. Tarayıcı: http://${VM_HOST}/"
