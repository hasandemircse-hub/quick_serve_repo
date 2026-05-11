#!/usr/bin/env bash
# Yerel Chrome: .env.edge içindeki EDGE_API_URL / CLOUD_API_URL ile --dart-define verir.
# Düz `flutter run -d chrome` kullanma; o zaman CLOUD varsayılanı localhost:8080 olur ve login reddedilir.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR"

if [[ -f "$REPO_ROOT/.env.edge" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.env.edge"
  set +a
fi

EDGE="${EDGE_API_URL:-http://127.0.0.1:8081/api}"
CLOUD="${CLOUD_API_URL:-http://192.168.139.157/api}"

echo "EDGE_API_URL  -> $EDGE"
echo "CLOUD_API_URL -> $CLOUD"
exec flutter run -d chrome \
  --dart-define=API_URL="$EDGE" \
  --dart-define=EDGE_API_URL="$EDGE" \
  --dart-define=CLOUD_API_URL="$CLOUD" \
  "$@"
