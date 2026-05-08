# Load Test Baseline (Order/Payment)

Bu doküman `scripts/load_test_order_payment.sh` için hızlı kullanım notudur.

## Amaç

- Edge tarafında sipariş ve ödeme event üretim uçlarının yük altında davranışını görmek.
- p95 / p99 gecikme ve hata oranı için baseline üretmek.

## Çalıştırma

Önce servisleri ayağa kaldır:

```bash
./scripts/up_local_cloud_edge.sh --skip-smoke
```

Sonra load test:

```bash
./scripts/load_test_order_payment.sh
```

## Önemli Parametreler

- `EDGE_API_BASE_URL` (default: `http://localhost:8081/api`)
- `TOTAL_REQUESTS` (default: `200`)
- `CONCURRENCY` (default: `20`)
- `REQUEST_TIMEOUT_SECONDS` (default: `8`)
- `JWT_TOKEN` (opsiyonel; endpoint auth isterse verilir)

Örnek:

```bash
TOTAL_REQUESTS=1000 CONCURRENCY=50 ./scripts/load_test_order_payment.sh
```

## Beklenen Çıktı

- Her senaryo için:
  - `total`
  - `ok`
  - `fail`
  - `avg_ms`
  - `p95_ms`
  - `p99_ms`
- Genel özet:
  - `PASS / FAIL / WARN`

## Değerlendirme Kuralı (Script)

- `fail = 0` -> PASS
- `fail <= TOTAL_REQUESTS/20` -> WARN
- üstü -> FAIL

Not: Bu kural ilk baseline içindir; pilot sonrası SLO bazlı sıkılaştırılmalıdır.
