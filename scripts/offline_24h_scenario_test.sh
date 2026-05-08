#!/usr/bin/env bash

set -euo pipefail

# QuickServe edge offline resilience scenario
# Varsayılan olarak kısa prova (60sn) çalıştırır.
# Gerçek 24 saat testi için OFFLINE_SECONDS=86400 ver.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CLOUD_API_BASE_URL="${CLOUD_API_BASE_URL:-http://localhost:8080/api}"
EDGE_API_BASE_URL="${EDGE_API_BASE_URL:-http://localhost:8081/api}"
OFFLINE_SECONDS="${OFFLINE_SECONDS:-60}"
OFFLINE_EVENT_COUNT="${OFFLINE_EVENT_COUNT:-20}"
SYNC_RECOVERY_TIMEOUT_SECONDS="${SYNC_RECOVERY_TIMEOUT_SECONDS:-300}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf "${GREEN}PASS${NC} %s\n" "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf "${RED}FAIL${NC} %s\n" "$1"; }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); printf "${YELLOW}WARN${NC} %s\n" "$1"; }

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
}

check_http_200() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -sS -m 8 -o /tmp/qs_offline_resp.txt -w '%{http_code}' "$url" || true)"
  if [[ "$code" == "200" ]]; then
    pass "$label ($url)"
    return 0
  fi
  fail "$label ($url) -> HTTP $code"
  return 1
}

read_sync_field() {
  local field="$1"
  local body
  body="$(curl -sS -m 8 "$EDGE_API_BASE_URL/edge/system/sync-status" || true)"
  printf '%s' "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null || true
}

stop_cloud_stack() {
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml stop cloud-nginx cloud-backend cloud-postgres
}

start_cloud_stack() {
  docker compose --env-file .env.cloud -f docker-compose.cloud.yml up -d
}

wait_cloud_health() {
  local elapsed=0
  while [[ "$elapsed" -lt 180 ]]; do
    local code
    code="$(curl -sS -m 5 -o /tmp/qs_cloud_health.txt -w '%{http_code}' "$CLOUD_API_BASE_URL/actuator/health" || true)"
    if [[ "$code" == "200" ]]; then
      pass "Cloud health recovered"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  fail "Cloud health recovery timeout"
  return 1
}

produce_offline_events() {
  local i=1
  while [[ "$i" -le "$OFFLINE_EVENT_COUNT" ]]; do
    curl -sS -m 5 -X POST "$EDGE_API_BASE_URL/waiter/orders" \
      -H "Content-Type: application/json" \
      -d "{\"tableId\":\"T${i}\",\"note\":\"offline-test-${i}\"}" >/dev/null || true
    i=$((i + 1))
  done
}

wait_sync_recovery() {
  local elapsed=0
  while [[ "$elapsed" -lt "$SYNC_RECOVERY_TIMEOUT_SECONDS" ]]; do
    local pending retry dead
    pending="$(read_sync_field "outboxPendingCount")"
    retry="$(read_sync_field "outboxRetryCount")"
    dead="$(read_sync_field "outboxDeadCount")"
    if [[ "${pending:-}" == "0" && "${retry:-}" == "0" && "${dead:-}" == "0" ]]; then
      pass "Outbox queue drained after reconnect"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  fail "Outbox recovery timeout (pending/retry/dead sıfırlanmadı)"
  return 1
}

main() {
  require_cmd curl
  require_cmd python3
  require_cmd docker

  echo "== QuickServe Offline Scenario Test =="
  echo "CLOUD_API_BASE_URL=$CLOUD_API_BASE_URL"
  echo "EDGE_API_BASE_URL=$EDGE_API_BASE_URL"
  echo "OFFLINE_SECONDS=$OFFLINE_SECONDS"
  echo "OFFLINE_EVENT_COUNT=$OFFLINE_EVENT_COUNT"
  echo "SYNC_RECOVERY_TIMEOUT_SECONDS=$SYNC_RECOVERY_TIMEOUT_SECONDS"
  echo

  check_http_200 "Cloud health" "$CLOUD_API_BASE_URL/actuator/health" || true
  check_http_200 "Edge health" "$EDGE_API_BASE_URL/actuator/health" || true

  echo "-- 1) Cloud stack durduruluyor --"
  stop_cloud_stack
  pass "Cloud stack stopped"

  echo "-- 2) Offline işlem üretimi --"
  produce_offline_events
  pass "Offline events produced: $OFFLINE_EVENT_COUNT"

  echo "-- 3) Offline bekleme penceresi --"
  sleep "$OFFLINE_SECONDS"
  pass "Offline window completed (${OFFLINE_SECONDS}s)"

  local pending_before
  pending_before="$(read_sync_field "outboxPendingCount")"
  if [[ -n "$pending_before" && "$pending_before" != "0" ]]; then
    pass "Outbox birikimi doğrulandı (pending=$pending_before)"
  else
    fail "Outbox birikimi bekleniyordu ama pending=$pending_before"
  fi

  echo "-- 4) Cloud stack yeniden başlatılıyor --"
  start_cloud_stack
  wait_cloud_health || true

  echo "-- 5) Sync recovery doğrulaması --"
  wait_sync_recovery || true

  echo
  echo "== Sonuç Özeti =="
  echo "PASS: $PASS_COUNT"
  echo "FAIL: $FAIL_COUNT"
  echo "WARN: $WARN_COUNT"

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    pass "Offline senaryo testi başarıyla tamamlandı."
    exit 0
  fi

  warn "Offline senaryo testinde başarısız adımlar var. Log ve sync-status kontrol edilmeli."
  exit 1
}

main "$@"
