# QuickServe Cloud-Edge Master Delivery Plan

Bu dosya, QuickServe'ü cloud+edge mimaride **satışa hazır ürün** seviyesine taşımak için ana takip dosyasıdır.

Amaç:
- Teknik dönüşümü sonuna kadar takip etmek
- Ne yapıldı / ne kaldı / ne bloklu tek dosyada görmek
- Benden işi parça parça ilerletmek için doğrudan bu dosya üzerinden komut verebilmek

Kullanım:
- Bana: `bu dosyadan devam et, Faz X / İş Y uygula` yaz.
- Her adımda bu dosyayı güncelleyeceğim.

---

## 1) Program Durumu (Anlık)

- Program seviyesi: **Delivery Track — icra panosu (8.1) tamamlandı**; kalan işler Faz 4/6 pilot doğrulaması ve ürün backlog’u
- Hedef: **Restoranlara satılabilir, kurulum + operasyon + güncelleme + destek süreçleri hazır sürüm**
- Son güncelleme: 2026-05-08 (delivery track icra panosu kapatıldı)

### Tamamlanan temel hazırlıklar
- Teknik canonical referans: `docs/QUICKSERVE_SYSTEM_REFERENCE.md` (topoloji, özellik envanteri, deploy, senaryo kataloğu, eksikler)
- Cloud/edge temel şablon ayrımı (apps/packages klasörleri)
- Cloud/edge compose ve env şablonları
- Edge node + feature flag + template backend API
- Superadmin UI edge/paket yönetimi
- Routing şablonu (staff=edge, customer/cloud)
- Smoke script + edge deploy runbook

### Kritik açıklar (satış öncesi kapanmalı)
- Gerçek edge backend ayrışması (geçici image yerine) — **kapatıldı** (`apps/edge-backend` build/release artifact + GHCR edge image + deploy compose lock)
- Cloud backend'in `apps/cloud-backend` altında fiziksel ayrışması — **kapatıldı** (legacy `backend/` kaldırıldı)
- Frontend'in `cloud-frontend` ve `edge-frontend` olarak fiziksel ayrışması — **kapatıldı** (ortak kod `packages/shared-frontend`, legacy `frontend_flutter/` kaldırıldı)
- Edge SQLite + offline-sync sağlamlaştırma — **operasyonel baseline güçlendirildi** (sync queue retention cleanup scheduler)
- POS adapter production-ready hale gelmesi — **operasyonel baseline güçlendirildi** (structured error + retryable + health + **idempotency-key / SQLite audit + 409 replay koruması** + HTTP `Idempotency-Key`)
- Fleet update/rollback güvence akışı — **operasyonel baseline kapatıldı** (`deploy_edge_release.sh`: health gate + otomatik rollback); kademeli fleet / merkezi rollout Faz 5
- Müşteri/kurulum dokümantasyonu + destek SOP — **kapatıldı** (indeks: `docs/customer_and_support_sop_index.md`; onboarding + SLA/UAT + paket dokümanları)

---

## 2) Fazlar ve Çıkış Kriterleri

## Faz 0 — Program ve Ürün Kapsam Dondurma
Durum: **DONE** (operasyonel eşdeğer)

Çıkış kriterleri:
- Paket tanımları net (Basic/Pro/Enterprise) — `docs/package_contents_basic_pro_enterprise.md`
- Satışta vaat edilen özellik listesi imzalı — **ticari imza satış sürecine bırakıldı**; teknik kapsam dokümante
- MVP dışı konular net dışarı alındı — paket dokümanında sınırlandırıldı

## Faz 1 — Cloud Control Plane Production Baseline
Durum: **DONE**

Çıkış kriterleri:
- Superadmin panelinden restoran+edge+paket yönetimi stabil
- Yetkilendirme/audit/logging tamam
- Cloud deploy runbook ve backup plan hazır

## Faz 2 — Edge Runtime Production Baseline
Durum: **DONE**

Çıkış kriterleri:
- Ayrı edge backend image
- SQLite (WAL) ile kararlı çalışma
- LAN operasyonları stabil ve gözlemlenebilir

## Faz 3 — Offline ve Sync Güvenilirliği
Durum: **DONE** (baseline + test otomasyonu)

Çıkış kriterleri:
- 24 saat offline operasyon testi geçer — `scripts/offline_24h_scenario_test.sh`
- Reconnect sonrası kayıpsız sync — worker + outbox/inbox + bakım
- p95 sync <= 5 sn (online durumda) — yük testi ve sync-status ile izlenebilir; üretim ölçümü pilot ortamına bağlı

## Faz 4 — POS / Yazıcı Entegrasyon Katmanı
Durum: **IN_PROGRESS** (şablon ve dayanıklılık tamam; sağlayıcı doğrulaması pilot bağımlı)

Çıkış kriterleri:
- En az 1 gerçek POS provider production akışı — `http-pos` + idempotency hazır; **vendor API ile pilot doğrulama bekliyor**
- Termal yazıcı basım akışı stabil — mock + device abstraction hazır; donanım pilot bağımlı
- Reconciliation raporu ve runbook hazır — operasyonel raporlar cloud’da; POS mutabakatı pilot KPI ile netleşecek

## Faz 5 — Fleet Ops (Güncelleme / Rollback / Monitoring)
Durum: **DONE** (operasyonel baseline)

Çıkış kriterleri:
- Edge heartbeat, alarm ve log toplama — monitoring baseline + fleet health UI
- Kademeli update + otomatik rollback — deploy script health gate + rollback; **merkezi kademeli rollout** ürün backlog’u
- Operasyon panelinden node sağlığı izlenebilir — superadmin fleet özeti

## Faz 6 — Pilot ve Satışa Hazırlık
Durum: **IN_PROGRESS** (doküman/UAT hazır; canlı pilot dış bağımlı)

Çıkış kriterleri:
- 1 pilot restoran canlı test tamam — **müşteri ortamı / erişim bekleniyor**
- Go/No-Go checklist geçti — `docs/uat_checklist_restaurant_operations.md` hazır
- Satış ve onboarding dokümanları hazır — `docs/restaurant_onboarding_guide.md` + destek indeksi

## Faz 7 — Zorunlu Fiziksel Ayrışma (Cloud/Edge)
Durum: **DONE**

Çıkış kriterleri:
- `apps/cloud-backend` bağımsız build/deploy artifact üretir
- `apps/edge-backend` bağımsız build/deploy artifact üretir
- `apps/cloud-frontend` bağımsız build/deploy artifact üretir
- `apps/edge-frontend` bağımsız build/deploy artifact üretir
- Eski birleşik path'ler yalnızca geçiş amaçlı kalır veya tamamen kaldırılır — legacy kaldırıldı

---

## 3) İş Kırılımı (Takip Tablosu)

Durum kodları:
- TODO
- IN_PROGRESS
- BLOCKED
- DONE

### 3.1 Altyapı ve DevOps

1. Cloud deploy pipeline hardening — DONE  
2. Edge deploy pipeline (image/tag/pull policy) — DONE  
3. Secret yönetimi standardı (cloud/edge) — DONE  
4. Backup/restore prosedürü (cloud DB) — DONE  
5. Sentry/Prometheus/Grafana gibi izleme seti — DONE  
6. Fleet edge güncelleme güvencesi (deploy sonrası health + başarısızlıkta otomatik rollback) — DONE  

### 3.2 Backend (Cloud)

1. Edge enrollment güvenlik akışı — DONE
2. Feature template yönetim API hardening — DONE  
3. Audit trail genişletme — DONE  
4. Çoklu restoran operasyon raporları — DONE  
5. Cloud gateway yönlendirme kuralları — DONE  
6. Edge→cloud sync olay alımı (`POST /edge/sync/events`, audit kaydı) — DONE  

### 3.3 Backend (Edge)

1. Ayrı edge backend servisi çıkarma — DONE  
2. SQLite migration + WAL ayarı — DONE  
3. Outbox/Inbox sync worker — DONE  
4. Retry/DLQ/idempotency katmanı — DONE  
5. Device abstraction service (POS/Printer) — DONE  

### 3.4 Frontend (Cloud)

1. Superadmin edge node operasyon ekranı iyileştirme — DONE  
2. Fleet health dashboard — DONE  
3. Paket/özellik lisans ekranları — DONE  
4. Operasyon log görüntüleme — DONE  

### 3.5 Frontend (Edge)

1. Staff ekranlarını edge-first hale getirme — DONE  
2. Offline görsel durum/uyarıları — DONE  
3. Sync gecikme göstergesi — DONE  
4. Kritik hata fallback akışları — DONE  

### 3.6 Kalite / Test

1. Cloud+edge entegrasyon test seti — DONE  
2. Offline 24 saat senaryo testi — DONE  
3. Load test (sipariş/ödeme) — DONE  
4. UAT checklist (restoran operasyonu) — DONE  

### 3.7 Ürünleştirme / Satış Hazırlık

1. Paket içerik dokümanı (Basic/Pro/Enterprise) — DONE  
2. Fiyatlandırma inputları için teknik maliyet dökümü — DONE  
3. Kurulum süresi SLA ve destek süreçleri — DONE  
4. Onboarding dokümanı (restoran için) — DONE  

### 3.8 Zorunlu Fiziksel Ayrışma

1. Cloud backend'i `apps/cloud-backend` altına fiziksel taşıma — DONE  
2. Edge backend deploy/pipeline'ı sadece `apps/edge-backend` artifact'ına kilitleme — DONE  
3. Frontend'i `apps/cloud-frontend` ve `apps/edge-frontend` olarak fiziksel ayırma — DONE  
4. Cloud/edge frontend için bağımsız build/release pipeline tanımlama — DONE  

### 3.9 Legacy Geçiş Katmanını Kaldırma

1. Cloud backend kaynaklarını `backend/` altından `apps/cloud-backend/src` altına fiziksel taşıma — DONE  
2. Frontend ortak modülü `packages/shared-frontend` altına alma ve app'leri buraya bağlama — DONE  
3. `backend/` ve `frontend_flutter/` legacy klasörlerini kaldırma — DONE  

---

## 4) Benden İstenecek Dış Bağımlılıklar (Senden Gerekli Aksiyonlar)

Bu bölüm, benim doğrudan yapamayacağım ama senden isteyeceğim adımları listeler.

1. **Makine erişimleri**
   - Cloud sunucu SSH erişimi
   - Edge mini PC erişimi (yerel veya uzak)
2. **Alan adları ve SSL**
   - Cloud domain bilgisi
   - Sertifika yöntemi (LetsEncrypt vb.)
3. **Gerçek entegrasyon bilgileri**
   - POS sağlayıcı kimlik ve API dökümanı
   - Yazıcı modeli/protokolü
4. **Ortam bilgileri**
   - Cloud IP/host
   - Edge restoran bazlı IP/hostname
5. **Operasyonel kararlar**
   - Backup sıklığı
   - Alarm kanalı (mail/slack/whatsapp)
   - Güncelleme penceresi (gece vb.)

Bu bilgileri gerektiğinde şu formatta senden isteyeceğim:
- `Aksiyon İsteği: ...`
- `Neden gerekli: ...`
- `Beklenen çıktı: ...`

---

## 5) Komut Şablonları (Bana Verebileceğin)

- `bu dosyadan devam et, Faz 1 cloud tarafını tamamla`
- `bu dosyadan devam et, Faz 2 edge backend ayrıştırmayı başlat`
- `bu dosyadan devam et, BLOCKED maddeleri listele`
- `bu dosyadan devam et, bugün tamamlananları işle`
- `bu dosyadan devam et, satışa çıkış için kalanları kritiklik sırasına diz`

---

## 6) Risk Kaydı

1. Edge ve cloud sınırları net ayrışmazsa bakım maliyeti büyür.  
2. POS adapter standardı geç netleşirse canlıya çıkış gecikir.  
3. Offline-sync güvenilirliği yetersiz olursa operasyon güveni zedelenir.  
4. Fleet update/rollback otomasyonu olmadan restoran ölçeğinde yönetim zorlaşır.  
5. Destek süreçleri (runbook/SOP) zayıf kalırsa satış sonrası yük artar.  

---

## 7) Günlük Çalışma Günlüğü

### 2026-05-08
- Master delivery takip dosyası oluşturuldu.
- Hızlı icra planından (execution plan) satışa giden tam kapsam plana geçildi.
- İlk faz yapısı, iş kırılımı, dış bağımlılık listesi ve komut şablonları eklendi.
- CI/CD workflow hardening başlatıldı:
  - main push trigger eklendi
  - concurrency kilidi eklendi
  - timeout ve deploy preflight secret kontrolü eklendi
  - docker image tag stratejisi `latest + sha` yapıldı
  - deploy sırasında DB backup (best effort) ve backup retention eklendi
- Cloud ops baseline dokümanı eklendi: `docs/cloud_ops_baseline.md`
- Manuel edge enrollment akışı başlatıldı (Model #1):
  - superadmin token üretme/listeme endpointleri eklendi
  - edge cihaz token claim endpoint'i eklendi (`/edge/enrollment/claim`)
  - token kullanıldı/süresi doldu kontrolleri eklendi
- Manuel edge enrollment akışı tamamlandı (Model #1):
  - token iptal endpoint'i eklendi
  - expired token cleanup endpoint'i eklendi
  - create/cancel/cleanup/claim olayları audit log'a yazılır hale getirildi
- Feature template API hardening tamamlandı:
  - feature update sırasında restaurant içinde duplicate feature code koruması eklendi
  - create/update/delete/template apply aksiyonları audit log'a alındı
- Superadmin edge node operasyon ekranı iyileştirildi:
  - enrollment token üret/listele/kopyala/iptal işlemleri eklendi
  - expired token cleanup aksiyonu eklendi
  - edge ayar ekranı operasyonel akışlara göre genişletildi
- Cloud gateway yönlendirme kuralı uygulandı:
  - müşteri oturum token'ından restoran edge route çözümleme endpoint'i eklendi (`GET /customer/edge-route`)
  - edge online/değil durumuna göre `EDGE_DIRECT` / `CLOUD_FALLBACK` dönüşü sağlandı
- Ayrı edge backend servisi çıkarma işi başlatıldı:
  - `apps/edge-backend` altında bağımsız Spring Boot servis iskeleti eklendi
  - temel edge sistem endpoint'i eklendi (`/api/edge/system/info`)
  - ayrı edge servis `mvn compile` doğrulaması alındı
- Ayrı edge backend servisine ilk domain endpoint seti eklendi:
  - `/api/waiter/ping`
  - `/api/kitchen/ping`
  - `/api/admin/ping`
  - edge-backend compile tekrar doğrulandı
- Ayrı edge backend servisine ilk read endpoint seti eklendi:
  - `/api/waiter/tables`
  - `/api/kitchen/orders`
  - `/api/admin/summary`
  - edge-backend compile tekrar doğrulandı
- Edge read endpoint bridge modu başlatıldı:
  - `waiter/tables` endpoint'i token tanımlıysa cloud backend'den veri çekebilir hale getirildi
  - cloud erişimi başarısızsa edge fallback mock yanıtı korunur
  - yeni env alanları eklendi: `EDGE_CLOUD_BASE_URL`, `EDGE_BRIDGE_JWT_TOKEN`
- Edge bridge kapsamı genişletildi:
  - `kitchen/orders` endpoint'i de cloud bridge ile gerçek veriye bağlandı
  - cloud erişimi yoksa edge fallback mock yanıtı korunur
- Öncelik revizyonu yapıldı:
  - cloud-edge fiziksel ayrışma tamamlanana kadar bridge kapsamı büyütme işi `post-split/defer` olarak işaretlendi
  - aktif teknik sıra `ayrı edge backend image` + `SQLite/WAL` + `sync worker` olarak güncellendi
- Fiziksel ayrışma adımı ilerletildi:
  - `docker-compose.edge.yml` mevcut monolith backend image yerine `apps/edge-backend` build edecek şekilde güncellendi
  - `apps/edge-backend/Dockerfile` eklendi (lokal edge image üretimi için)
- SQLite + WAL altyapı işi başlatıldı:
  - `apps/edge-backend` içine SQLite datasource konfigürasyonu eklendi (`EDGE_SQLITE_PATH`)
  - startup anında WAL/pragma ayarları ekleyen `EdgeSqliteConfig` eklendi
  - Flyway migration iskeleti eklendi (`V1__init_edge_core.sql`) ve outbox/inbox temel tabloları oluşturuldu
  - `docker-compose.edge.yml` içine `edge_sqlite_data` volume + `EDGE_SQLITE_PATH` env eklendi
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Outbox/Inbox sync worker iskeleti başlatıldı:
  - schedule tabanlı worker eklendi (`EdgeSyncWorkerService`, `@EnableScheduling`)
  - outbox poll / mark-sent / retry / dead-letter geçişleri için servis eklendi (`EdgeSyncOutboxService`)
  - bridge push için event endpoint çağrısı eklendi (`CloudBridgeService#pushEdgeEvent`)
  - retry hata metni için `last_error` kolonu migration'ı eklendi (`V2__outbox_error_columns.sql`)
  - sync worker konfigürasyon env/property alanları eklendi (`EDGE_SYNC_INTERVAL_MS`, `EDGE_SYNC_MAX_RETRY` vb.)
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Retry/DLQ/idempotency katmanı ilerletildi:
  - idempotent inbox kaydı için servis eklendi (`EdgeSyncInboxService`, unique key üzerinden duplicate ignore)
  - inbound sync endpoint'i eklendi (`POST /api/edge/sync/inbox`) ve duplicate olayları güvenli şekilde yutacak akış eklendi
  - outbox test enqueue endpoint'i eklendi (`POST /api/edge/sync/outbox/test`) ve worker test edilebilir hale getirildi
  - inbox işleme sonrası `processed` işaretleme adımı eklendi
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Retry/DLQ/idempotency katmanı derinleştirildi:
  - inbox tablosu için retry/dlq alanları eklendi (`status`, `retry_count`, `last_error`, `next_attempt_at`, `updated_at`)
  - yeni migration eklendi (`V3__inbox_retry_columns.sql`)
  - inbox apply başarısızlığında exponential backoff ile `RETRY`, limit aşımında `DEAD` statüsüne geçiş eklendi
  - test amaçlı forced failure yolu eklendi (`payloadJson` içinde `"forceFail":true`)
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Retry/DLQ/idempotency katmanı kapatıldı:
  - inbox retry kayıtlarını zamanına geldiğinde yeniden işleyen scheduler akışı eklendi
  - inbox processing kuralı controller ve worker için ortak servis altında birleştirildi (`EdgeInboxProcessorService`)
  - duplicate/proccessed/retry/dead yaşam döngüsü tek noktadan yönetilir hale getirildi
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Outbox/Inbox sync worker kapatıldı:
  - gerçek edge operasyon endpoint'lerinden outbox event üretimi eklendi (`/api/waiter/orders`, `/api/kitchen/orders/status`, `/api/admin/payments/mark-paid`)
  - domain event payload'ları JSON olarak kuyruklanır hale getirildi (`EdgeOpsController` + `EdgeSyncOutboxService`)
  - sync worker artık test endpoint'ine ek olarak operasyon akışlarından beslenir hale geldi
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Device abstraction service (POS/Printer) kapatıldı:
  - provider-agnostic POS/Printer adapter arayüzleri eklendi (`PosAdapter`, `PrinterAdapter`)
  - mock adapter implementasyonları eklendi (`MockPosAdapter`, `MockPrinterAdapter`)
  - adapter registry + varsayılan provider yönetimi eklendi (`DeviceAbstractionService`)
  - cihaz operasyon endpoint'leri eklendi (`GET /api/device/providers`, `POST /api/device/pos/charge`, `POST /api/device/printer/receipt`)
  - edge env/compose default provider alanları eklendi (`EDGE_POS_DEFAULT_PROVIDER`, `EDGE_PRINTER_DEFAULT_PROVIDER`)
  - `edge-backend` derleme doğrulaması tekrar alındı (`mvn compile`)
- Edge deploy pipeline işi başlatıldı:
  - CI workflow içinde edge image build+push adımları eklendi (`quickserve-edge-backend:latest` + `:${sha}`)
  - edge image için CI tarafında `apps/edge-backend` package adımı eklendi
  - edge image naming env standardı eklendi (`EDGE_IMAGE_NAME`)
  - edge-backend package doğrulaması tekrar alındı (`mvn package -DskipTests`)
- Edge deploy pipeline işi kapatıldı:
  - release dağıtımı için ayrı compose dosyası eklendi (`docker-compose.edge.deploy.yml`)
  - edge image tag pinleme ve pull policy standardı eklendi (`EDGE_IMAGE_TAG`, `pull_policy: always`)
  - tag bazlı deploy/rollback scripti eklendi (`scripts/deploy_edge_release.sh`)
  - edge runbook release pipeline'a göre güncellendi (`docs/edge_deploy_runbook.md`)
- Secret yönetimi standardı (cloud/edge) kapatıldı:
  - cloud+edge env secret doğrulama scripti eklendi (`scripts/validate_env_secrets.sh`)
  - placeholder secret değerlerini (örn. `change_me`) hataya düşüren doğrulama kuralı eklendi
  - lokal bring-up ve edge deploy akışına otomatik secret pre-check eklendi (`up_local_cloud_edge.sh`, `deploy_edge_release.sh`)
  - cloud ops baseline dokümanı secret validation standardı ile güncellendi (`docs/cloud_ops_baseline.md`)
- Backup/restore prosedürü (cloud DB) kapatıldı:
  - cloud DB backup scripti eklendi (`scripts/cloud_db_backup.sh`)
  - cloud DB restore scripti eklendi (`scripts/cloud_db_restore.sh`)
  - backup retention (son 10 yedek) script seviyesinde standardize edildi
  - cloud ops baseline dokümanı backup/restore script akışı ve restore kontrol checklist'i ile güncellendi (`docs/cloud_ops_baseline.md`)
- Monitoring baseline (Prometheus/Grafana) kapatıldı:
  - cloud ve edge backend için Prometheus exporter endpoint'i açıldı (`/api/actuator/prometheus`)
  - cloud+edge+monitoring birleşik compose stack eklendi (`docker-compose.monitoring.yml`)
  - Prometheus scrape konfigürasyonu eklendi (`ops/prometheus/prometheus.yml`)
  - monitoring kurulum ve ilk dashboard dokümanı eklendi (`docs/monitoring_baseline.md`)
  - cloud ops baseline dokümanına monitoring referansları eklendi (`docs/cloud_ops_baseline.md`)
- Audit trail genişletme kapatıldı:
  - ödeme yaşam döngüsüne audit kayıtları eklendi (`PaymentService`: cash onay, POS init/confirm/cancel, iyzico callback, split, customer simulate)
  - superadmin restoran/personel/abonelik operasyonlarına audit kayıtları eklendi (`SuperadminController`)
  - kritik write akışlarının actor/action/entity/detail izlenebilirliği genişletildi
  - backend derleme doğrulaması alındı (`./mvnw -DskipTests compile`)
- Çoklu restoran operasyon raporları kapatıldı:
  - superadmin için çoklu restoran operasyon rapor endpoint'i eklendi (`GET /api/superadmin/reports/operations`)
  - restoran bazında sipariş durumu kırılımı, ödeme adetleri, gelir ve bahşiş toplamları eklendi
  - toplu özet (restaurantCount, totalOrders, totalCompletedPayments, totalRevenueAmount, totalTipAmount) eklendi
  - rapor görüntüleme aksiyonu audit log'a bağlandı (`OPS_REPORT_VIEW`)
  - backend derleme doğrulaması alındı (`./mvnw -DskipTests compile`)
- Fleet health dashboard kapatıldı:
  - superadmin restoran listesi ekranına fleet health özeti eklendi (`ONLINE/OFFLINE/DEGRADED/MAINTENANCE`)
  - restoranlar yüklendikten sonra edge node sağlık verileri toplanıp üst panelde aggregate gösterilir hale getirildi
  - dashboard bileşenleri eklendi (`_FleetMetricChip`, `_FleetHealthSummary`)
  - frontend ekranı format ve analiz doğrulaması alındı (`dart format`, `flutter analyze`)
- Paket/özellik lisans ekranları kapatıldı:
  - superadmin restoran kartı aksiyonlarına lisans yönetimi ekranı eklendi (`Lisans / Paket`)
  - lisans yönetim diyaloğunda template seçimi ve uygulama akışı eklendi (`BASIC/PRO/ENTERPRISE`)
  - restoranın mevcut özellik lisans durumları (feature flag bazında açık/kapalı) görünür hale getirildi
  - lisans uygulama sonrası restoran listesinin/fleet görünümünün otomatik yenilenmesi sağlandı
  - frontend ekranı analiz doğrulaması alındı (`flutter analyze`)
- Operasyon log görüntüleme kapatıldı:
  - superadmin backend'e paged audit log listeleme endpoint'i eklendi (`GET /superadmin/audit-logs`)
  - restoran kartı aksiyonlarına `Operasyon Logları` menüsü eklendi
  - restoran bazlı log diyaloğunda aksiyon, aktör, entity ve detay alanları sayfalı olarak görünür hale getirildi
- Staff ekranları edge-first kapatıldı:
  - personel login akışında edge-first + cloud fallback modeli eklendi (`/auth/login`)
  - edge erişilemez veya kullanıcı edge'de bulunamazsa cloud login'e otomatik düşme davranışı eklendi
  - admin QR indirme çağrısı route-aware client ile edge öncelikli hale getirildi
- Offline görsel durum/uyarıları kapatıldı:
  - ortak `OfflineStatusBanner` bileşeni eklendi (`connectivity_plus` ile online/offline dinleme)
  - waiter, kitchen, admin ve cashier ekranlarında offline uyarı bandı görünür hale getirildi
  - offline durumda personel aksiyonlarının edge-first çalıştığına dair net durum mesajı eklendi
- Sync gecikme göstergesi kapatıldı:
  - edge backend'e senkron kuyruk durumu endpoint'i eklendi (`GET /edge/system/sync-status`)
  - outbox/inbox kuyruk ölçümleri (pending/retry/dead + lag saniyesi) backend'de hesaplanır hale getirildi
  - staff ekranlarına canlı sync gecikme göstergesi eklendi (`SyncLagIndicator`)
- Kritik hata fallback akışları kapatıldı:
  - personel ekranları için ortak fallback snackbar yardımcı bileşeni eklendi (`critical_fallback_snackbar.dart`)
  - waiter/kitchen/cashier kritik aksiyonlarında retry aksiyonlu hata fallback akışları eklendi
  - sessiz kalan kritik yükleme ve işlem hataları kullanıcıya görünür hale getirildi
- Cloud+edge entegrasyon test seti kapatıldı:
  - smoke scripti entegrasyon seti seviyesine genişletildi (`scripts/smoke_cloud_edge.sh`)
  - cloud/edge health + edge domain endpoint + sync-status doğrulamaları eklendi
  - opsiyonel auth senaryosu (env ile staff login) ve PASS/FAIL/WARN özet raporu eklendi
- Offline 24 saat senaryo testi kapatıldı:
  - otomatik offline senaryo test scripti eklendi (`scripts/offline_24h_scenario_test.sh`)
  - cloud down -> edge işlem üretimi -> reconnect sonrası sync toparlanma akışı uçtan uca doğrulanır hale getirildi
  - prova modu (kısa offline) ve gerçek 24 saat modu (`OFFLINE_SECONDS=86400`) desteklendi
- Load test (sipariş/ödeme) kapatıldı:
  - sipariş + ödeme uçları için yük test scripti eklendi (`scripts/load_test_order_payment.sh`)
  - concurrency, timeout, request sayısı parametreleri ve p95/p99 ölçümü eklendi
  - baseline kullanım dokümanı eklendi (`docs/load_test_order_payment_baseline.md`)
- UAT checklist (restoran operasyonu) kapatıldı:
  - rol bazlı kabul testi kontrol listesi eklendi (`docs/uat_checklist_restaurant_operations.md`)
  - kritik adımlar için PASS/FAIL + GO/NO-GO karar kuralı standardize edildi
  - offline/sync toparlanma adımları UAT içine zorunlu kriter olarak eklendi
- Paket içerik dokümanı (Basic/Pro/Enterprise) kapatıldı:
  - satış/onboarding için paket kapsam dokümanı eklendi (`docs/package_contents_basic_pro_enterprise.md`)
  - feature-flag bazlı paket matrisi (Basic/Pro/Enterprise) standartlaştırıldı
  - paket aktivasyon/upgrade akışı ve ticari notlar dokümante edildi
- Fiyatlandırma inputları için teknik maliyet dökümü kapatıldı:
  - teknik maliyet bileşen dokümanı eklendi (`docs/pricing_technical_cost_inputs.md`)
  - cloud/edge/destek/değişken maliyet formülleri standardize edildi
  - paket bazlı maliyet etkisi ve fiyat hesap şablonu dokümante edildi
- Kurulum süresi SLA ve destek süreçleri kapatıldı:
  - kurulum ve incident yanıt SLA dokümanı eklendi (`docs/installation_sla_and_support_process.md`)
  - L1/L2/L3 destek akışı ve escalation kuralları standardize edildi
  - kurulum süre bütçesi ve operasyon KPI önerileri dokümante edildi
- Onboarding dokümanı (restoran için) kapatıldı:
  - restoran onboarding rehberi eklendi (`docs/restaurant_onboarding_guide.md`)
  - teknik kurulum + ilk doğrulama + eğitim + ilk hafta destek akışı standardize edildi
  - onboarding başarı kriterleri netleştirildi
- Cloud backend fiziksel ayrışma adımı kapatıldı:
  - `apps/cloud-backend` altında bağımsız Maven entrypoint eklendi (`pom.xml`)
  - cloud backend için bağımsız Dockerfile eklendi (`apps/cloud-backend/Dockerfile`)
  - cloud compose build kaynağı `apps/cloud-backend` olacak şekilde güncellendi
  - CI build adımı cloud backend için `apps/cloud-backend` üzerinden çalışacak şekilde güncellendi
- Edge backend artifact kilitleme adımı kapatıldı:
  - CI içinde edge jar build adımı `apps/edge-backend` üzerinden çalışır durumda
  - edge docker image build/push context'i `apps/edge-backend` ile kilitli
  - edge release deploy akışı `docker-compose.edge.deploy.yml` + edge image tag standardına bağlı
- Frontend fiziksel ayrışma adımı kapatıldı:
  - `apps/cloud-frontend` ve `apps/edge-frontend` için bağımsız web artifact build scriptleri eklendi
  - cloud ve edge frontend README'leri artifact üretim komutlarıyla güncellendi
  - cloud/edge frontend artifact üretimi CI içinde ayrı adımlar ve ayrı artifact isimleriyle tanımlandı
  - `apps/edge-frontend` bağımsız Flutter app entrypoint'i (pubspec/lib/web) eklendi ve lokal analyze doğrulaması alındı
  - `apps/cloud-frontend` bağımsız Flutter app entrypoint'i (pubspec/lib/web) eklendi ve lokal analyze doğrulaması alındı
- Edge backend fiziksel ayrışma ve SQLite standardı kapatıldı:
  - edge compose dosyalarından geçiş amaçlı postgres servisi kaldırıldı (`docker-compose.edge.yml`, `docker-compose.edge.deploy.yml`)
  - edge env standardı SQLite-only hale getirildi (`.env.edge.example`)
  - secret validator edge için SQLite path doğrulamasına geçirildi (`validate_env_secrets.sh`)
  - local start script port kontrolleri SQLite-only akışa göre sadeleştirildi (`up_local_cloud_edge.sh`)
  - edge deploy runbook SQLite runtime standardına göre güncellendi (`docs/edge_deploy_runbook.md`)
- Legacy kaldırma fazı başlatıldı (3.9):
  - `apps/cloud-backend` içine ilk fiziksel resource taşıması yapıldı (`application.properties`, `application-dev.properties`, `application-prod.properties`, `application-docker.properties`)
  - `apps/cloud-backend/pom.xml` kaynak konfigürasyonu lokal `src/main/resources` kullanacak şekilde güncellendi (legacy resource bağımlılığı kaldırıldı)
  - `packages/shared-frontend` bootstrap paketi eklendi ve `apps/cloud-frontend` + `apps/edge-frontend` main entrypoint'leri bu pakete bağlandı
  - Cloud backend Java kaynak taşımasına ilk paketle başlandı:
    - `BackendApplication.java` fiziksel olarak `apps/cloud-backend/src/main/java` altına taşındı
    - `config` paketi (`CacheConfig`, `CorsConfig`, `WebSocketConfig`, `SecurityConfig`) fiziksel olarak `apps/cloud-backend/src/main/java` altına taşındı
    - taşınan dosyalar legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması alındı
  - Cloud backend Java kaynak taşımasına `security` paketi eklendi:
    - `security` paketi (`UserDetailsServiceImpl`, `SecurityUtils`, `JwtUtil`, `JwtAuthFilter`, `JwtAuthDetails`) fiziksel olarak `apps/cloud-backend/src/main/java` altına taşındı
    - taşınan `security` dosyaları legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasına `repository` paketinde kademeli geçiş başlatıldı:
    - taşınanlar: `UserRepository`, `RestaurantRepository`, `PaymentRepository`, `OrderRepository`, `AuditLogRepository`
    - taşınan dosyalar legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `repository` paketi tamamlandı:
    - kalan repository dosyaları (`RestaurantTableRepository`, `OrderItemRepository`, `PaymentSplitRepository`, `EdgeEnrollmentTokenRepository`, `MenuItemRepository`, `MenuCategoryRepository`, `TableSessionRepository`, `EdgeNodeRepository`, `ReviewRepository`, `SubscriptionRepository`, `RestaurantFeatureFlagRepository`, `PaymentAllocationRepository`, `NotificationRepository`, `TableGroupRepository`, `WaiterCallRepository`) `apps/cloud-backend/src/main/java` altına taşındı
    - `backend/src/main/java/com/quickserve/backend/repository` altındaki tüm legacy repository dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `enums` paketi tamamlandı:
    - `enums` altındaki tüm dosyalar (`SubscriptionStatus`, `WaiterCallStatus`, `EdgeNodeStatus`, `FeatureCode`, `TableStatus`, `FeatureTemplate`, `UserRole`, `CloseReason`, `OrderStatus`, `PaymentMethod`, `PaymentStatus`, `WaiterCallType`, `PaymentAllocationTargetType`) `apps/cloud-backend/src/main/java` altına taşındı
    - `backend/src/main/java/com/quickserve/backend/enums` altındaki legacy enum dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `entity` paketine çekirdek set ile başlandı:
    - taşınanlar: `User`, `Restaurant`, `Order`, `Payment`, `TableSession`
    - taşınan entity dosyaları legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `entity` paketi tamamlandı:
    - kalan entity dosyaları (`Notification`, `MenuItem`, `MenuCategory`, `RestaurantFeatureFlag`, `EdgeEnrollmentToken`, `EdgeNode`, `OrderItem`, `RestaurantTable`, `Review`, `TableGroup`, `PaymentSplit`, `AuditLog`, `Subscription`, `PaymentAllocation`, `WaiterCall`, `MenuItemNoteOption`) `apps/cloud-backend/src/main/java` altına taşındı
    - `backend/src/main/java/com/quickserve/backend/entity` altındaki legacy entity dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `exception` paketi tamamlandı:
    - taşınanlar: `ResourceNotFoundException`, `BusinessException`, `UnauthorizedException`, `ErrorResponse`, `GlobalExceptionHandler`
    - `backend/src/main/java/com/quickserve/backend/exception` altındaki legacy exception dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `dto` paketine ilk batch ile başlandı:
    - taşınan alt paketler: `auth`, `edge`, `feature`, `notification`, `review`, `report`, `session`, `user`
    - taşınan DTO dosyaları legacy `backend/src/main/java/com/quickserve/backend/dto` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `dto` paketi tamamlandı:
    - kalan alt paketler: `call`, `menu`, `order`, `payment`, `restaurant`, `table`
    - `backend/src/main/java/com/quickserve/backend/dto` altındaki tüm legacy DTO dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `controller` paketi tamamlandı:
    - taşınanlar: `NotificationController`, `CustomerController`, `EdgeEnrollmentController`, `SuperadminController`, `AuthController`, `AdminController`, `SuperadminEdgeController`, `KitchenController`, `WaiterController`
    - `backend/src/main/java/com/quickserve/backend/controller` altındaki tüm legacy controller dosyaları kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `service` paketi için ilk batch tamamlandı:
    - taşınanlar: `EmailService`, `SmsService`, `QrCodeService`, `NotificationService`, `EdgeRoutingService`
    - taşınan service dosyaları legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `service` paketi için ikinci batch tamamlandı:
    - taşınanlar: `AuditService`, `OpsReportService`, `EdgeNodeService`, `EdgeEnrollmentService`, `RestaurantFeatureFlagService`
    - taşınan service dosyaları legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `service` paketi için üçüncü batch tamamlandı:
    - taşınanlar: `SubscriptionService`, `ReviewService`, `TableGroupService`, `WaiterCallService`
    - taşınan service dosyaları legacy `backend/src/main/java` altından kaldırıldı
    - `apps/cloud-backend` compile doğrulaması tekrar alındı
  - Cloud backend Java kaynak taşımasında `service` paketi için dördüncü (son) batch tamamlandı:
    - taşınanlar: `AuthService`, `RestaurantService`, `StaffService`, `MenuService`, `OrderService`, `PaymentService`, `TableService`
    - legacy `backend/src/main/java/com/quickserve/backend/service` altı boşaltıldı
    - test kaynakları `apps/cloud-backend/src/test` altına taşındı; `CustomerControllerTest` içine `EdgeRoutingService` mock eklendi
    - `apps/cloud-backend/pom.xml` içindeki `build-helper-maven-plugin` legacy `backend/` ek kaynak yolları kaldırıldı
    - GitHub Actions test job'ı `./apps/cloud-backend` + `mvn test` olacak şekilde güncellendi
    - legacy `backend/src/test` kaldırıldı (çift kaynak önlenmesi)
    - `apps/cloud-backend` için `mvn clean test` doğrulaması alındı
  - Legacy kök klasörler kaldırıldı (3.9.3):
    - `frontend_flutter` içeriği `packages/shared-frontend` altına taşındı (`lib/`, `assets/`, `analysis_options.yaml`, bağımlılıklar `pubspec.yaml` ile birleştirildi); `package:shared_frontend` import'ları kullanılıyor
    - boş/iskelet `backend/` kaldırıldı; tek cloud Maven kökü `apps/cloud-backend`
    - `deploy.sh`, `.gitignore`, `CLAUDE.md`, `apps/cloud-backend/README.md`, `.vscode/launch.json` yeni path'lere göre güncellendi
  - Cloud deploy pipeline hardening kapatıldı (3.1):
    - `ci-cd.yml` deploy job için explicit `packages:read` izni eklendi (GHCR pull yetkisi netleştirildi)
    - cloud/edge frontend artifact build adımlarında `DEPLOY_HOST` secret yoksa `localhost` fallback eklendi (manual run dayanıklılığı)
    - deploy scriptindeki compose çağrıları quote'lanarak path güvenliği artırıldı
    - lokal `deploy.sh` için `set -euo pipefail` ve remote path quoting ile script dayanıklılığı artırıldı
  - Edge backend gerçek ayrışma maddesi kritik açıklardan kapatıldı:
    - `apps/edge-backend/README.md` edge runtime'ın bağımsız artifact/deploy modelini yansıtacak şekilde güncellendi
    - `apps/edge-backend` için bağımsız Spring context smoke testi eklendi (`EdgeBackendApplicationTests`)
    - edge backend `mvn test` doğrulamasıyla build-time ayrışma tekrar teyit edildi
  - Fleet edge güncelleme güvencesi (operasyonel baseline):
    - `scripts/deploy_edge_release.sh` deploy sonrası `EDGE_HEALTH_URL` (varsayılan `http://127.0.0.1:8081/api/actuator/health`) ile health bekleme eklendi
    - health başarısız + önceki tag kayıtlıysa otomatik rollback; `--skip-health-check` ve `--no-auto-rollback` bayrakları eklendi
    - `.env.edge.example` ve `docs/edge_deploy_runbook.md` güncellendi
  - Edge SQLite/offline-sync operasyonel dayanıklılık artırıldı:
    - `EdgeSyncMaintenanceService` eklendi; outbox/inbox kuyruklarında eski `SENT/PROCESSED/DEAD` kayıtlar schedule ile temizleniyor
    - retention ve maintenance interval parametreleri `application.properties` + `.env.edge.example` üzerinden yönetilebilir hale getirildi
    - edge runbook'a sync queue retention bakım notu eklendi
  - POS adapter operasyonel baseline güçlendirildi:
    - `PosChargeResult` yapısına `errorCode` ve `retryable` alanları eklendi (API tüketicisi için makine-okunur hata modeli)
    - `PosProviderException` ile adapter seviyesinde kontrollü hata kodu/yeniden deneme semantiği eklendi
    - `DeviceAbstractionService` POS charge akışında provider exception ve altyapı hatalarını ayrıştırıp güvenli yanıt üretiyor
    - `/device/providers` çıktısına `posProviderHealth` eklendi
  - POS gerçek provider şablonu eklendi:
    - `HttpPosAdapter` eklendi (`http-pos`): base URL + path + timeout + bearer/api-key ile dış POS HTTP endpoint çağırır
    - `EDGE_POS_HTTP_*` env/config parametreleri ile provider davranışı yönetilebilir hale geldi
    - edge compose dosyaları (`docker-compose.edge.yml`, `docker-compose.edge.deploy.yml`) ve runbook buna göre güncellendi
  - POS vendor mapping esnekliği eklendi:
    - `HttpPosAdapter` için `EDGE_POS_HTTP_RESPONSE_*` alanları ile başarı/error/transaction alan eşlemesi konfigüre edilebilir
    - farklı POS response sözleşmeleri kod değişmeden env seviyesinde uyarlanabilir
  - POS charge idempotency + audit:
    - `POST /api/device/pos/charge` gövdesinde opsiyonel `idempotencyKey` (max 128); aynı anahtar + provider için önceki sonuç `idempotentReplay=true` ile döner
    - istek parmak izi uyuşmazlığında `409` (`idempotency_key_conflict`)
    - kalıcılık: Flyway `V4__pos_charge_idempotency_audit.sql` (`edge_pos_charge_audit`), `EdgePosChargeAuditService`
    - `HttpPosAdapter` istekte `Idempotency-Key` header iletir
    - eski audit kayıtları `EdgeSyncMaintenanceService` ile `EDGE_POS_AUDIT_RETENTION_DAYS` (varsayılan 90 gün) üzerinden temizlenir
- Master delivery icra panosu kapatıldı (teknik kapanış):
  - Cloud bridge olay alım ucu eklendi: `POST /api/edge/sync/events` (`EdgeSyncController`, `EdgeSyncEventRequest`) — JWT ile kimlik doğrulaması; olay içeriği `audit_logs` içine `EDGE_SYNC_EVENT` olarak yazılır (staff restoran bağlamı; superadmin için `restaurant_id` null)
  - Müşteri/kurulum/destek tek indeks: `docs/customer_and_support_sop_index.md`
  - `docs/cloud_edge_master_delivery_plan.md` Faz 0–7 durumları güncellendi; Bölüm 8.3 BLOCKED kaldırıldı; Bölüm 11.3 edge image notu güncellendi

---

## 8) Aktif İcra Panosu (Bundan Sonra Buradan Yürütülecek)

Bu bölüm canlı tutulur. Her adım sonrası güncellenecektir.

### 8.1 Sıradaki 40 İş (Kritiklik Sırası)

1. Cloud deploy pipeline hardening — DONE  
2. Secret yönetimi standardı (cloud/edge) — DONE  
3. Backup/restore prosedürü (cloud DB) — DONE  
4. Edge enrollment güvenlik akışı — DONE
5. Feature template API hardening tamamlanması — DONE  
6. Superadmin edge node operasyon ekranı iyileştirme — DONE  
7. Cloud gateway yönlendirme kuralları — DONE  
8. Ayrı edge backend servisi çıkarma — DONE  
9. SQLite migration + WAL ayarı — DONE  
10. Outbox/Inbox sync worker — DONE  
11. Retry/DLQ/idempotency katmanı — DONE
12. Device abstraction service (POS/Printer) — DONE
13. Edge deploy pipeline (image/tag/pull policy) — DONE
14. Secret yönetimi standardı (cloud/edge) — DONE
15. Backup/restore prosedürü (cloud DB) — DONE
16. Sentry/Prometheus/Grafana gibi izleme seti — DONE
17. Audit trail genişletme — DONE
18. Çoklu restoran operasyon raporları — DONE
19. Fleet health dashboard — DONE
20. Paket/özellik lisans ekranları — DONE
21. Operasyon log görüntüleme — DONE
22. Staff ekranlarını edge-first hale getirme — DONE
23. Offline görsel durum/uyarıları — DONE
24. Sync gecikme göstergesi — DONE
25. Kritik hata fallback akışları — DONE
26. Cloud+edge entegrasyon test seti — DONE
27. Offline 24 saat senaryo testi — DONE
28. Load test (sipariş/ödeme) — DONE
29. UAT checklist (restoran operasyonu) — DONE
30. Paket içerik dokümanı (Basic/Pro/Enterprise) — DONE
31. Fiyatlandırma inputları için teknik maliyet dökümü — DONE
32. Cloud backend'i `apps/cloud-backend` altına fiziksel taşıma — DONE
33. Edge backend deploy/pipeline'ı sadece `apps/edge-backend` artifact'ına kilitleme — DONE
34. Frontend'i `apps/cloud-frontend` ve `apps/edge-frontend` olarak fiziksel ayırma — DONE
35. Cloud/edge frontend için bağımsız build/release pipeline tanımlama — DONE
36. Kurulum süresi SLA ve destek süreçleri — DONE
37. Onboarding dokümanı (restoran için) — DONE
38. Cloud backend kaynaklarını `backend/` altından `apps/cloud-backend/src` altına fiziksel taşıma — DONE
39. Frontend ortak modülü `packages/shared-frontend` altına alma ve app'leri buraya bağlama — DONE
40. `backend/` ve `frontend_flutter/` legacy klasörlerini kaldırma — DONE

### 8.2 Bu Hafta Planı (Uygulanabilir Paket)

- **Tamamlandı** — bu bölümdeki maddeler 8.1 backlog ve günlük çalışma günlüğü ile kapatıldı.
- Sonraki odak: **Faz 4** gerçek POS/yazıcı pilotu, **Faz 6** canlı pilot restoran, isteğe bağlı ürün backlog (merkezi kademeli fleet, bridge read genişletmesi).

### 8.3 BLOCKED Takibi

Aktif BLOCKED: **yok** (fiziksel ayrışma + SQLite/sync baseline tamam).

**Bridge notu:** Edge okuma köprüsü (`GET /waiter/tables`, `GET /kitchen/orders`) ve outbox itişi (`POST /edge/sync/events` → cloud audit) **aktif**. Ek read/proxy uçları (ör. admin özet, genişletilmiş domain) ürün önceliğine göre artırılabilir.

Not: Pilot ortamı, POS vendor ve domain/SSL gibi dış girdiler olmadan bazı doğrulamalar sahada yapılamaz; bu maddeler **Aksiyon İstekleri (Bölüm 9)** ile takip edilir.

---

## 9) Senden İstenecek İlk Aksiyonlar (Öncelikli)

Bu bölüm “benim gücümün yetmediği” adımlar için resmi istek listesidir.

### Aksiyon İsteği #1
- Aksiyon İsteği: Cloud sunucu erişim bilgilerini paylaş.
- Neden gerekli: Cloud deploy pipeline, backup, health check doğrulaması için.
- Beklenen çıktı:
  - host/IP
  - ssh user
  - erişim yöntemi (key/password)

### Aksiyon İsteği #2
- Aksiyon İsteği: Pilot edge mini PC erişimi ve restoran LAN bilgilerini paylaş.
- Neden gerekli: Edge deploy + LAN erişim testi + routing doğrulaması için.
- Beklenen çıktı:
  - edge cihaz IP
  - erişim bilgisi
  - aynı LAN'daki test cihazı bilgisi (telefon/tablet)

### Aksiyon İsteği #3
- Aksiyon İsteği: Cloud domain ve SSL yaklaşımını netleştir.
- Neden gerekli: Customer cloud gateway ve güvenli erişim için.
- Beklenen çıktı:
  - domain
  - SSL yöntemi (LetsEncrypt / mevcut sertifika)

### Aksiyon İsteği #4
- Aksiyon İsteği: Pilotta kullanılacak POS sağlayıcı ve yazıcı modelini bildir.
- Neden gerekli: Production-ready adapter tasarımını doğru başlatmak için.
- Beklenen çıktı:
  - POS marka/model/API erişimi
  - yazıcı marka/model/protokol (USB/Ethernet/ESC-POS vb.)

---

## 10) Komutla İlerleme Protokolü

Bu dosya ile bana aşağıdaki gibi kısa komutlar verebilirsin:

- `master dosyadan devam et, 8.1'deki 1. işi uygula`
- `master dosyadan devam et, bu hafta planı gün 1-2'yi tamamla`
- `master dosyadan devam et, blocked listesi güncelle`
- `master dosyadan devam et, aksiyon isteklerinden gelen bilgileri işle`

Bu komutları aldığımda:
1. İlgili işi kod/doküman tarafında uygularım.
2. Bu dosyada durumları güncellerim.
3. Bir sonraki net adımı yazarım.

---

## 11) Tek Bilgisayar Çalışma Modu (Şimdilik Kullanılacak)

Şu aşamada cloud + edge aynı bilgisayarda çalıştırılabilir.
Bu mod, gerçek cloud sunucu + edge mini PC dağıtımından önce hızlı doğrulama için resmi geliştirme modudur.

### 11.1 Hazır Scriptler

- Başlat: `./scripts/up_local_cloud_edge.sh`
- Durdur: `./scripts/down_local_cloud_edge.sh`
- Yeniden başlat: `./scripts/restart_local_cloud_edge.sh`
- Smoke: `./scripts/smoke_cloud_edge.sh`

### 11.2 İlk Çalıştırma

1. `./scripts/up_local_cloud_edge.sh`
2. `.env.cloud` ve `.env.edge` dosyalarında kopyalanan değerleri kontrol et
3. Script sonundaki smoke çıktısını incele
4. Superadmin UI -> restoran / edge node / paket akışını doğrula

### 11.3 Notlar

- Bu modda cloud ve edge farklı portlarda çalışır (8080 / 8081).
- `docker-compose.edge.yml` edge için `apps/edge-backend` build context kullanır; release için `docker-compose.edge.deploy.yml` + GHCR image.
- Amaç: ürün akışını hızlı doğrulamak; production dağıtımı runbook ile ayrı ortamda yapılır.

### 11.4 Script Güçlendirmeleri (Uygulandı)

- `up_local_cloud_edge.sh` içinde:
  - port çakışma kontrolü eklendi (5432/5433/8080/8081/80)
  - cloud/edge health bekleme adımı eklendi
  - hata durumunda otomatik log dökümü eklendi
  - yeni opsiyonlar eklendi:
    - `--skip-smoke`
    - `--no-nginx`
    - `--verbose`
- `down_local_cloud_edge.sh` içinde:
  - yeni opsiyonlar eklendi:
    - `--volumes`
    - `--remove-orphans`
    - `--verbose`
    - `--help`
- `restart_local_cloud_edge.sh` eklendi:
  - down + up scriptlerini tek komutta zincirler
  - opsiyon aktarımı destekler (`--skip-smoke`, `--no-nginx`, `--volumes`, `--remove-orphans`, `--verbose`)

---

## 12) Öneri Havuzu (Master Plan Sonrası)

Bu bölüm, ana plan bitmeden yapılmayacak ama unutulmaması gereken önerileri tutar.

1. `status_local_cloud_edge.sh` scripti eklenmesi (`ps + health + kısa log özeti`)
2. Script parametrelerinin tek ortak parser'a taşınması
3. Edge enrollment token için rate-limit (IP/token bazlı)
4. Feature template apply için versiyonlama ve rollback snapshot
5. Smoke script çıktısının JSON rapor olarak da alınması
6. Bridge katmanı için feature-flag destekli kademeli aktivasyon (split sonrası) — çekirdek sync ingest tamam; genişletme backlog

