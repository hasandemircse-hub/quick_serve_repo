# Cloud Ops Baseline

Bu doküman Faz 1 için cloud operasyon temel standardını tanımlar.

## 1) Secret Standardı

Zorunlu deploy secret'ları:
- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_PATH`
- `DEPLOY_SSH_KEY`

Önerilen uygulama:
- Secret'ları yalnızca CI environment (`production`) içinde tut.
- Secret'ları düzenli döndür (en az 90 günde bir).
- `.env` dosyasını sunucuda tut, repoya ekleme.

Cloud+edge `.env` doğrulaması:

```bash
./scripts/validate_env_secrets.sh --all
```

Kontrol kapsamı (asgari):
- Cloud: `CLOUD_DB_PASSWORD`, `CLOUD_JWT_SECRET`, `SUPERADMIN_PASSWORD`
- Edge: `EDGE_NODE_ID`, `EDGE_RESTAURANT_ID`, `EDGE_CLOUD_BASE_URL`, `EDGE_ENROLLMENT_TOKEN`, `EDGE_SQLITE_PATH` (edge runtime SQLite; `scripts/validate_env_secrets.sh` ile uyumlu)

Not:
- `change_me`/`example` gibi placeholder değerler hata sayılır.
- `up_local_cloud_edge.sh` ve `deploy_edge_release.sh` bu doğrulamayı otomatik çalıştırır.

## 2) Deploy Pipeline Hardening Kuralları

- `main` push + manuel dispatch tetikleme
- Aynı branch için concurrency kilidi
- Job timeout'ları (test/build/deploy)
- Deploy öncesi secret preflight kontrolü
- Image tag stratejisi: `latest` + `sha`

## 3) Backup/Restore Baseline

Deploy sırasında:
- `postgres` servisinden zaman damgalı SQL dump alınır (`best effort`)
- Yedekler `$DEPLOY_PATH/backups` altında tutulur
- Son 10 yedek saklanır

Lokal/operasyon script standardı:

```bash
./scripts/cloud_db_backup.sh
./scripts/cloud_db_restore.sh --file backups/cloud-db/db-YYYYMMDD-HHMMSS.sql
```

Script notları:
- Varsayılan env dosyası: `.env.cloud`
- Varsayılan compose dosyası: `docker-compose.cloud.yml`
- Yedek klasörü: `backups/cloud-db`
- `cloud_db_backup.sh` her çalıştırmada retention (son 10 dosya) uygular

Restore (manuel):

```bash
cd "$DEPLOY_PATH"
docker compose --env-file .env exec -T postgres sh -lc \
  'psql -U "${POSTGRES_USER:-quickserve}" "${POSTGRES_DB:-quickserve}"' \
  < backups/db-YYYYMMDD-HHMMSS.sql
```

## 4) Operasyonel Kontrol Listesi

Deploy sonrası:
1. `/api/actuator/health` PASS
2. Superadmin login PASS
3. Restoran listesi PASS
4. Edge node/paket ekranı PASS

Restore sonrası:
1. `docker compose ... ps` ile `cloud-postgres`/`cloud-backend` up
2. `/api/actuator/health` PASS
3. Superadmin login PASS
4. Son kritik veri (restoran/sipariş/ödeme) tutarlılık kontrolü PASS

## 5) Monitoring Baseline

- Prometheus + Grafana stack dosyası: `docker-compose.monitoring.yml`
- Prometheus scrape config: `ops/prometheus/prometheus.yml`
- Kurulum adımları ve ilk dashboard notları: `docs/monitoring_baseline.md`
