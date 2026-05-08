#!/usr/bin/env bash

set -euo pipefail

# QuickServe edge load test (order + payment)
# Basit bağımlılıklarla (curl + python3) p95 ve hata oranı üretir.

EDGE_API_BASE_URL="${EDGE_API_BASE_URL:-http://localhost:8081/api}"
TOTAL_REQUESTS="${TOTAL_REQUESTS:-200}"
CONCURRENCY="${CONCURRENCY:-20}"
REQUEST_TIMEOUT_SECONDS="${REQUEST_TIMEOUT_SECONDS:-8}"
JWT_TOKEN="${JWT_TOKEN:-}"

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

check_edge_health() {
  local code
  code="$(curl -sS -m 5 -o /tmp/qs_load_health.txt -w '%{http_code}' "$EDGE_API_BASE_URL/actuator/health" || true)"
  if [[ "$code" == "200" ]]; then
    pass "Edge health hazır"
    return 0
  fi
  fail "Edge health hazır değil (HTTP $code)"
  return 1
}

run_scenario() {
  local scenario="$1"
  local url="$2"
  local body_template="$3"
  local out_file="$4"

  : >"$out_file"
  local i=1
  while [[ "$i" -le "$TOTAL_REQUESTS" ]]; do
    while [[ "$(jobs -pr | wc -l | tr -d ' ')" -ge "$CONCURRENCY" ]]; do
      wait -n || true
    done

    {
      local payload
      payload="$(printf "$body_template" "$i")"
      local code time_total
      if [[ -n "$JWT_TOKEN" ]]; then
        read -r code time_total < <(
          curl -sS -m "$REQUEST_TIMEOUT_SECONDS" -o /dev/null \
            -w '%{http_code} %{time_total}' \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -d "$payload" || echo "000 0"
        )
      else
        read -r code time_total < <(
          curl -sS -m "$REQUEST_TIMEOUT_SECONDS" -o /dev/null \
            -w '%{http_code} %{time_total}' \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$payload" || echo "000 0"
        )
      fi
      printf '%s,%s,%s\n' "$scenario" "$code" "$time_total" >>"$out_file"
    } &

    i=$((i + 1))
  done
  wait
}

summarize_results() {
  local label="$1"
  local file="$2"
  local summary
  summary="$(python3 - "$file" <<'PY'
import csv, sys, statistics
path = sys.argv[1]
rows = list(csv.reader(open(path)))
codes = [r[1] for r in rows if len(r) >= 3]
times = [float(r[2]) * 1000.0 for r in rows if len(r) >= 3]
ok = [c for c in codes if c.startswith("2")]
fail = len(codes) - len(ok)
times_sorted = sorted(times)
def pct(arr, p):
    if not arr:
        return 0.0
    k = (len(arr)-1) * p
    f = int(k)
    c = min(f + 1, len(arr)-1)
    if f == c:
        return arr[f]
    return arr[f] + (arr[c]-arr[f]) * (k-f)
avg = statistics.mean(times) if times else 0.0
p95 = pct(times_sorted, 0.95)
p99 = pct(times_sorted, 0.99)
print(f"{len(codes)},{len(ok)},{fail},{avg:.2f},{p95:.2f},{p99:.2f}")
PY
)"
  IFS=',' read -r total ok fail_count avg_ms p95_ms p99_ms <<<"$summary"

  echo "[$label] total=$total ok=$ok fail=$fail_count avg_ms=$avg_ms p95_ms=$p95_ms p99_ms=$p99_ms"
  if [[ "${fail_count:-0}" -eq 0 ]]; then
    pass "$label hata oranı kabul edilebilir (0 hata)"
  elif [[ "${fail_count:-0}" -le $((TOTAL_REQUESTS / 20)) ]]; then
    warn "$label düşük seviyede hata içeriyor (fail=$fail_count)"
  else
    fail "$label yüksek hata oranı (fail=$fail_count)"
  fi
}

main() {
  require_cmd curl
  require_cmd python3

  echo "== QuickServe Load Test: Order + Payment =="
  echo "EDGE_API_BASE_URL=$EDGE_API_BASE_URL"
  echo "TOTAL_REQUESTS=$TOTAL_REQUESTS"
  echo "CONCURRENCY=$CONCURRENCY"
  echo "REQUEST_TIMEOUT_SECONDS=$REQUEST_TIMEOUT_SECONDS"
  echo

  check_edge_health || true

  local order_results payment_results
  order_results="$(mktemp /tmp/qs_load_order_XXXX.csv)"
  payment_results="$(mktemp /tmp/qs_load_payment_XXXX.csv)"

  echo "-- 1) ORDER_CREATED load --"
  run_scenario \
    "order" \
    "$EDGE_API_BASE_URL/waiter/orders" \
    '{"tableId":"LT-%s","note":"load-order-%s"}' \
    "$order_results"
  summarize_results "Order create" "$order_results"

  echo "-- 2) PAYMENT_MARKED_PAID load --"
  run_scenario \
    "payment" \
    "$EDGE_API_BASE_URL/admin/payments/mark-paid" \
    '{"paymentId":"LT-PAY-%s","method":"CASH"}' \
    "$payment_results"
  summarize_results "Payment mark-paid" "$payment_results"

  rm -f "$order_results" "$payment_results"

  echo
  echo "== Sonuç Özeti =="
  echo "PASS: $PASS_COUNT"
  echo "FAIL: $FAIL_COUNT"
  echo "WARN: $WARN_COUNT"

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    pass "Load test seti tamamlandı."
    exit 0
  fi

  warn "Load test setinde kritik bulgular var. p95/hata oranı incelenmeli."
  exit 1
}

main "$@"
