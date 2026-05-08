#!/usr/bin/env bash

set -euo pipefail

# QuickServe Cloud-Edge integration smoke set
# Amaç: cloud+edge temel entegrasyon uçlarını hızlıca doğrulamak.

CLOUD_API_BASE_URL="${CLOUD_API_BASE_URL:-http://localhost:8080/api}"
EDGE_API_BASE_URL="${EDGE_API_BASE_URL:-http://localhost:8081/api}"
CLOUD_WEB_URL="${CLOUD_WEB_URL:-http://localhost}"
STAFF_USERNAME="${STAFF_USERNAME:-}"
STAFF_PASSWORD="${STAFF_PASSWORD:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "${GREEN}PASS${NC} %s\n" "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf "${YELLOW}WARN${NC} %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "${RED}FAIL${NC} %s\n" "$1"
}

check_http_ok() {
  local label="$1"
  local url="$2"
  local expected="${3:-200}"
  local code
  code="$(curl -sS -m 8 -o /tmp/qs_smoke_resp.txt -w '%{http_code}' "$url" || true)"
  if [[ "$code" == "$expected" ]]; then
    pass "$label ($url) -> HTTP $code"
    return 0
  fi
  fail "$label ($url) -> HTTP $code (expected $expected)"
  return 1
}

check_http_json_field() {
  local label="$1"
  local url="$2"
  local field="$3"
  local expected="$4"
  local body
  body="$(curl -sS -m 8 "$url" || true)"
  local got
  got="$(printf '%s' "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('$field'); print(v if v is not None else '')" 2>/dev/null || true)"
  if [[ "$got" == "$expected" ]]; then
    pass "$label -> $field=$expected"
    return 0
  fi
  fail "$label -> $field=$got (expected $expected)"
  return 1
}

check_login_if_configured() {
  if [[ -z "$STAFF_USERNAME" || -z "$STAFF_PASSWORD" ]]; then
    warn "Auth senaryosu atlandı (STAFF_USERNAME/STAFF_PASSWORD tanımlı değil)."
    return 0
  fi

  local code
  local token
  code="$(curl -sS -m 8 -o /tmp/qs_login_resp.json -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$STAFF_USERNAME\",\"password\":\"$STAFF_PASSWORD\"}" \
    "$CLOUD_API_BASE_URL/auth/login" || true)"
  if [[ "$code" != "200" ]]; then
    fail "Cloud auth login ($STAFF_USERNAME) -> HTTP $code"
    return 1
  fi
  token="$(python3 -c "import json;print(json.load(open('/tmp/qs_login_resp.json')).get('token',''))" 2>/dev/null || true)"
  if [[ -z "$token" ]]; then
    fail "Cloud auth login token boş döndü"
    return 1
  fi
  printf '%s' "$token" > /tmp/qs_smoke_cloud_jwt.txt
  pass "Cloud auth login başarılı ($STAFF_USERNAME)"
}

check_cloud_edge_sync_ingest() {
  if [[ ! -s /tmp/qs_smoke_cloud_jwt.txt ]]; then
    warn "Cloud edge sync ingest atlandı (önce başarılı staff login gerekir)."
    return 0
  fi
  local token
  token="$(cat /tmp/qs_smoke_cloud_jwt.txt)"
  local code
  code="$(curl -sS -m 8 -o /tmp/qs_smoke_sync_resp.txt -w '%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d '{"eventId":"smoke-'"$(date +%s)"'","eventType":"SMOKE_TEST","payloadJson":"{}"}' \
    "$CLOUD_API_BASE_URL/edge/sync/events" || true)"
  if [[ "$code" == "202" ]]; then
    pass "Cloud edge sync ingest ($CLOUD_API_BASE_URL/edge/sync/events) -> HTTP 202"
    return 0
  fi
  fail "Cloud edge sync ingest -> HTTP $code (expected 202)"
  return 1
}

echo "== QuickServe Cloud-Edge Integration Smoke =="
echo "CLOUD_API_BASE_URL=$CLOUD_API_BASE_URL"
echo "EDGE_API_BASE_URL=$EDGE_API_BASE_URL"
echo "CLOUD_WEB_URL=$CLOUD_WEB_URL"
echo

echo "-- A) Core health --"
check_http_ok "Cloud health" "$CLOUD_API_BASE_URL/actuator/health" || true
check_http_ok "Edge health" "$EDGE_API_BASE_URL/actuator/health" || true
check_http_ok "Cloud web reachable" "$CLOUD_WEB_URL" || true

echo
echo "-- B) Edge domain endpoints --"
check_http_ok "Edge waiter ping" "$EDGE_API_BASE_URL/waiter/ping" || true
check_http_ok "Edge kitchen ping" "$EDGE_API_BASE_URL/kitchen/ping" || true
check_http_ok "Edge admin ping" "$EDGE_API_BASE_URL/admin/ping" || true
check_http_ok "Edge system info" "$EDGE_API_BASE_URL/edge/system/info" || true
check_http_ok "Edge sync status" "$EDGE_API_BASE_URL/edge/system/sync-status" || true
check_http_json_field "Edge sync level" "$EDGE_API_BASE_URL/edge/system/sync-status" "level" "OK" || true

echo
echo "-- C) Cloud auth (optional) --"
check_login_if_configured || true

echo
echo "-- D) Cloud edge sync ingest (optional, needs staff JWT) --"
check_cloud_edge_sync_ingest || true

echo
echo "== Manual Flow Checklist (E maddesi) =="
echo "1) Superadmin paneline gir ve restoran oluştur."
echo "2) Restoran için Edge / Paket Ayarları ekranından edge node ekle."
echo "3) Basic/Pro/Enterprise paket şablonlarından birini uygula."
echo "4) Edge node durumunu ONLINE/DEGRADED/MAINTENANCE olarak değiştir."
echo "5) UI'da güncel node durumu ve feature flag yansımasını doğrula."
echo
echo "== Sonuç Özeti =="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "WARN: $WARN_COUNT"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  pass "Cloud+edge entegrasyon smoke seti tamamlandı."
  exit 0
fi

warn "Entegrasyon smoke setinde hatalar var. Servisleri/logları kontrol et."
exit 1
