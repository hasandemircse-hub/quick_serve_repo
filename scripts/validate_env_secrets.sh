#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/validate_env_secrets.sh [--cloud|--edge|--all]

Options:
  --cloud   Validate .env.cloud
  --edge    Validate .env.edge
  --all     Validate both (default)
  --help    Show help
EOF
}

MODE="all"
case "${1:---all}" in
  --cloud) MODE="cloud" ;;
  --edge) MODE="edge" ;;
  --all) MODE="all" ;;
  --help|-h) usage; exit 0 ;;
  *) echo "Unknown option: ${1:-}"; usage; exit 1 ;;
esac

PLACEHOLDER_PATTERN='^(change_me|CHANGE_ME|example|TODO|replace_me)$'

check_file_exists() {
  local env_file="$1"
  if [[ ! -f "$env_file" ]]; then
    echo "ERROR: $env_file not found."
    return 1
  fi
  return 0
}

read_env_value() {
  local file="$1"
  local key="$2"
  local value
  value="$(awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,"",$0); print $0}' "$file" | tail -n 1)"
  echo "$value"
}

validate_keys() {
  local env_file="$1"
  shift
  local keys=("$@")
  local has_error=0

  for key in "${keys[@]}"; do
    local value
    value="$(read_env_value "$env_file" "$key")"
    if [[ -z "${value// }" ]]; then
      echo "ERROR: $env_file -> $key is missing or empty."
      has_error=1
      continue
    fi

    if [[ "$value" =~ $PLACEHOLDER_PATTERN ]]; then
      echo "ERROR: $env_file -> $key uses placeholder value: $value"
      has_error=1
    fi
  done

  return $has_error
}

validate_cloud() {
  local env_file=".env.cloud"
  check_file_exists "$env_file" || return 1
  validate_keys "$env_file" \
    CLOUD_DB_PASSWORD \
    CLOUD_JWT_SECRET \
    SUPERADMIN_PASSWORD
}

validate_edge() {
  local env_file=".env.edge"
  check_file_exists "$env_file" || return 1
  validate_keys "$env_file" \
    EDGE_NODE_ID \
    EDGE_RESTAURANT_ID \
    EDGE_CLOUD_BASE_URL \
    EDGE_ENROLLMENT_TOKEN \
    EDGE_SQLITE_PATH
}

case "$MODE" in
  cloud)
    validate_cloud
    ;;
  edge)
    validate_edge
    ;;
  all)
    validate_cloud
    validate_edge
    ;;
esac

echo "Secret validation PASSED ($MODE)."
