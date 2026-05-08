#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.edge"
COMPOSE_FILE="$ROOT_DIR/docker-compose.edge.deploy.yml"
STATE_DIR="$ROOT_DIR/.edge-release"
CURRENT_TAG_FILE="$STATE_DIR/current_tag"
PREVIOUS_TAG_FILE="$STATE_DIR/previous_tag"

# Override via env or optional EDGE_HEALTH_URL in .env.edge
EDGE_HEALTH_URL="${EDGE_HEALTH_URL:-}"

SKIP_HEALTH_CHECK="false"
NO_AUTO_ROLLBACK="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy_edge_release.sh --tag <image_tag>
  ./scripts/deploy_edge_release.sh --rollback

Options:
  --tag <image_tag>      Deploy specific EDGE_IMAGE_TAG (updates .env.edge)
  --rollback             Roll back to previous deployed tag (from .edge-release state)
  --skip-health-check    Do not wait for /actuator/health after compose up
  --no-auto-rollback     On health failure after --tag deploy, do not revert to previous tag
  --help                 Show this help message

Environment:
  EDGE_HEALTH_URL        Full URL for health probe (default: http://127.0.0.1:8081/api/actuator/health)
                         Set in shell or add EDGE_HEALTH_URL=... to .env.edge
EOF
}

ensure_prerequisites() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Copy from .env.edge.example first."
    exit 1
  fi
  mkdir -p "$STATE_DIR"
  "$ROOT_DIR/scripts/validate_env_secrets.sh" --edge
}

# Best-effort: pick EDGE_HEALTH_URL from .env.edge if not set in environment
load_health_url_from_env_file() {
  if [[ -n "$EDGE_HEALTH_URL" ]]; then
    return 0
  fi
  local line
  line="$(grep -E '^[[:space:]]*EDGE_HEALTH_URL=' "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$line" ]]; then
    EDGE_HEALTH_URL="${line#*=}"
    EDGE_HEALTH_URL="${EDGE_HEALTH_URL%\"}"
    EDGE_HEALTH_URL="${EDGE_HEALTH_URL#\"}"
    EDGE_HEALTH_URL="${EDGE_HEALTH_URL%\'}"
    EDGE_HEALTH_URL="${EDGE_HEALTH_URL#\'}"
  fi
  EDGE_HEALTH_URL="${EDGE_HEALTH_URL:-http://127.0.0.1:8081/api/actuator/health}"
}

set_env_tag() {
  local tag="$1"
  python3 - "$ENV_FILE" "$tag" <<'PY'
import sys
from pathlib import Path

env_file = Path(sys.argv[1])
tag = sys.argv[2]
lines = env_file.read_text().splitlines()
updated = False
for i, line in enumerate(lines):
    if line.startswith("EDGE_IMAGE_TAG="):
        lines[i] = f"EDGE_IMAGE_TAG={tag}"
        updated = True
        break
if not updated:
    lines.append(f"EDGE_IMAGE_TAG={tag}")
env_file.write_text("\n".join(lines) + "\n")
PY
}

wait_for_edge_health() {
  local max_attempts="${1:-18}"
  local sleep_s="${2:-10}"
  local i
  echo "Edge health bekleniyor: $EDGE_HEALTH_URL (en fazla $((max_attempts * sleep_s))s)"
  for i in $(seq 1 "$max_attempts"); do
    if curl -sfS -m 8 "$EDGE_HEALTH_URL" >/dev/null 2>&1; then
      echo "Edge health OK ($i/$max_attempts)."
      return 0
    fi
    echo "  Deneme $i/$max_attempts — henüz hazır değil, ${sleep_s}s bekleniyor..."
    sleep "$sleep_s"
  done
  echo "ERROR: Edge health check başarısız: $EDGE_HEALTH_URL"
  return 1
}

compose_up() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull edge-backend
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
}

# deploy_tag <tag> <allow_auto_rollback true|false>
deploy_tag() {
  local tag="$1"
  local allow_auto_rollback="${2:-true}"
  local current_tag=""

  if [[ -f "$CURRENT_TAG_FILE" ]]; then
    current_tag="$(<"$CURRENT_TAG_FILE")"
  fi

  if [[ -n "$current_tag" && "$current_tag" != "$tag" ]]; then
    echo "$current_tag" > "$PREVIOUS_TAG_FILE"
  fi

  set_env_tag "$tag"
  compose_up

  load_health_url_from_env_file

  if [[ "$SKIP_HEALTH_CHECK" != "true" ]]; then
    if ! wait_for_edge_health; then
      if [[ "$allow_auto_rollback" == "true" && "$NO_AUTO_ROLLBACK" != "true" && -f "$PREVIOUS_TAG_FILE" ]]; then
        local prev
        prev="$(<"$PREVIOUS_TAG_FILE")"
        if [[ -n "$prev" && "$prev" != "$tag" ]]; then
          echo "WARN: Yeni sürüm sağlıksız; otomatik rollback: $prev"
          deploy_tag "$prev" false
        fi
      fi
      exit 1
    fi
  fi

  echo "$tag" > "$CURRENT_TAG_FILE"
  echo "Edge deploy OK. Active tag: $tag"
}

rollback() {
  if [[ ! -f "$PREVIOUS_TAG_FILE" ]]; then
    echo "ERROR: No previous tag found for rollback."
    exit 1
  fi
  local rollback_tag
  rollback_tag="$(<"$PREVIOUS_TAG_FILE")"
  deploy_tag "$rollback_tag" false
}

main() {
  local tag=""
  local do_rollback="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        shift
        tag="${1:-}"
        if [[ -z "$tag" ]]; then
          echo "ERROR: --tag requires a value"
          exit 1
        fi
        ;;
      --rollback)
        do_rollback="true"
        ;;
      --skip-health-check)
        SKIP_HEALTH_CHECK="true"
        ;;
      --no-auto-rollback)
        NO_AUTO_ROLLBACK="true"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift || true
  done

  ensure_prerequisites

  if [[ "$do_rollback" == "true" ]]; then
    rollback
    exit 0
  fi

  if [[ -z "$tag" ]]; then
    echo "ERROR: provide --tag or --rollback"
    usage
    exit 1
  fi

  deploy_tag "$tag" true
}

main "$@"
