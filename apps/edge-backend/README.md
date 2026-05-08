# edge-backend

Restoran içi edge backend uygulaması (cloud backend'den bağımsız runtime).

## Bu klasörde hazır olanlar
- Bağımsız Spring Boot edge servisi (`apps/edge-backend`)
- SQLite + Flyway migration altyapısı
- Edge sync worker (outbox/inbox/retry) ve device abstraction katmanı
- `/api/edge/system/info` endpoint'i
- Health endpoint (`/api/actuator/health`)
- Edge node/restaurant env tabanlı kimlik alanları

## Çalıştırma (lokal)
```bash
cd apps/edge-backend
mvn spring-boot:run
```

## Deploy notu
- Lokal geliştirme için `docker-compose.edge.yml` build context: `apps/edge-backend`
- Release dağıtımı için `docker-compose.edge.deploy.yml` + GHCR edge image (`quickserve-edge-backend`)
- POS tarafında `mock-pos` yanında gerçek provider entegrasyon şablonu olarak `http-pos` adapter bulunur (env ile aktif edilir); charge isteğinde opsiyonel `idempotencyKey` ile SQLite audit + tekrarlı yanıt (`idempotentReplay`) desteklenir.
