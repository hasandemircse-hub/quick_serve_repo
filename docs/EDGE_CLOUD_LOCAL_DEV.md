# Edge (IDE) ↔ Cloud (yerel VM) — geliştirme checklist

Senaryo: **PostgreSQL + cloud-backend** bir VM’de (veya aynı ağdaki makinede), **edge-backend** senin bilgisayarında VS Code ile.

## TODO sırası

1. **[ ] VM cloud** — `docker compose` veya `mvn spring-boot:run`; health: `http://<VM_IP>/api/actuator/health` → 200.
2. **[ ] `.env.edge` (IDE)** — `EDGE_CLOUD_BASE_URL=http://<VM_IP>/api` (mutlaka `/api` ile bitsin). `EDGE_RESTAURANT_ID` doğru restoran.
3. **[ ] Köprü JWT** — Cloud’da **superadmin** web → restoran → **Edge / Paket ayarları** → **1 haftalık token üret** → **Köprü anahtarını al** → çıkan uzun metni `EDGE_BRIDGE_JWT_TOKEN` yapıştır. (Swagger gerekmez.)
4. **[ ] Edge çalıştır** — VS Code launch: `Spring Boot-EdgeBackendApplication<edge-backend>` (`envFile`: `.env.edge`).
5. **[ ] Doğrulama** — Mac’ten: `http://127.0.0.1:8081/api/edge/system/cloud-probe`  
   Beklenen: `snapshot`, `waiterTables`, `waiterMenu`, `kitchenOrders`, `syncEventPush` alanlarında `OK ...`. `FAIL` görürsen mesaj cloud tarafı (403, süre, rol) ipucu verir.
6. **[ ] (İsteğe bağlı)** — `POST http://127.0.0.1:8081/api/edge/system/bootstrap/pull` ile snapshot’ı elle yenile.

## Edge’in cloud’dan kullandığı uçlar (köprü JWT ile)

| Amaç | Cloud yol |
|------|-----------|
| Offline snapshot | `GET /edge/bootstrap/snapshot?restaurantId=` |
| Garson masaları | `GET /waiter/tables` |
| Garson menü | `GET /waiter/menu` |
| Mutfak siparişleri | `GET /kitchen/orders` |
| Olay itme | `POST /edge/sync/events` |

Enrollment (JWT üretimi) herkese açık: `POST /edge/enrollment/claim` — superadmin panelindeki “Köprü anahtarını al” bunu çağırır.

## Sık sorun

- **403** — `EDGE_BRIDGE_JWT_TOKEN` enrollment kodu değil; claim sonrası `eyJ...` olmalı. VM’deki cloud ile token aynı `JWT_SECRET` ile üretilmiş olmalı.
- **`bridgeJwtShapeOk: false`** — `.env`’de token kırpılmış / satır kayması; tek satır `eyJ...` olduğundan emin ol.
