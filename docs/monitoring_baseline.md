# Monitoring Baseline (Prometheus + Grafana)

Bu doküman QuickServe cloud+edge için minimum izleme baseline'ını tanımlar.

## 1) Gereksinimler

- Cloud backend çalışıyor olmalı (`docker-compose.cloud.yml`)
- Edge backend çalışıyor olmalı (`docker-compose.edge.yml` veya `docker-compose.edge.deploy.yml`)

## 2) Monitoring Stack Başlatma

```bash
docker compose \
  --env-file .env.cloud \
  --env-file .env.edge \
  -f docker-compose.cloud.yml \
  -f docker-compose.edge.yml \
  -f docker-compose.monitoring.yml \
  up -d prometheus grafana
```

## 3) Endpointler

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Cloud metrics: `http://localhost:8080/api/actuator/prometheus`
- Edge metrics: `http://localhost:8081/api/actuator/prometheus`

## 4) Grafana İlk Kurulum

1. `http://localhost:3001` aç
2. `.env` değerleri ile login ol (`GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`)
3. Data source olarak Prometheus ekle:
   - URL: `http://prometheus:9090`
4. İlk dashboard için metrik önerileri:
   - `process_cpu_usage`
   - `jvm_memory_used_bytes`
   - `http_server_requests_seconds_count`

## 5) Operasyonel Not

- Bu baseline minimum seviyedir; alerting kural seti bir sonraki adımda genişletilecektir.
- Production ortamda Grafana admin şifresi varsayılan bırakılmamalıdır.
