# QuickServe Cloud-Edge Hızlı İcra Planı

Bu doküman detaylı mimari tartışması için değil, **en kısa sürede Cloud + Edge uygulamalarını ayağa kaldırmak** için hazırlanmıştır.

Bu dosya aynı zamanda çalışma hafızasıdır:
- Yapılanlar
- Sıradaki işler
- Blokajlar
- Devam komutu

Not:
- Satışa giden tüm kapsamlı takip bu dosyadan ayrı olarak
  `docs/cloud_edge_master_delivery_plan.md` dosyasına taşındı.
- Bu dosya hızlı icra/kurulum planı olarak kalır.

---

## 1) Hedef (Kısa ve Net)

14 gün içinde aşağıdaki sonucu almak:
- Cloud backend + cloud frontend çalışır durumda
- Edge backend + edge frontend çalışır durumda
- Superadmin panelinden restoran bazlı edge node ve paket şablonu yönetilebilir
- Restoran içinde (LAN) edge akışı test edilebilir

---

## 2) Scope (Bu Sprintte Var / Yok)

### Var
- Cloud kontrol düzlemi iskeleti
- Edge node kayıt/listeleme/durum/silme
- Feature flag + paket şablonu (Basic/Pro/Enterprise)
- Superadmin UI’den edge/paket yönetimi
- Tek komutla local/dev ortamda cloud + edge başlatma

### Yok (Sonraki Faz)
- Tam offline-sync motoru
- POS gerçek provider entegrasyonu (mock hariç)
- Otomatik fleet rollout/rollback (tam üretim seviyesi)
- Multi-region ve multi-cloud failover

---

## 3) Bugüne Kadar Yapılanlar

## Backend (tamamlandı)
- `EdgeNode` ve `RestaurantFeatureFlag` entity’leri eklendi.
- `EdgeNodeStatus`, `FeatureCode`, `FeatureTemplate` enum’ları eklendi.
- Repository, service ve controller katmanları eklendi.
- Superadmin altında yeni endpoint’ler açıldı:
  - Edge node CRUD
  - Feature flag CRUD
  - Feature template uygula endpoint’i
- Swagger operation/parameter açıklamaları eklendi.

## Frontend (tamamlandı)
- Superadmin restoran kartına **Edge / Paket Ayarları** ekranı eklendi.
- Edge node:
  - listeleme
  - ekleme
  - durum değiştirme
  - silme
- Feature flag:
  - tekil aç/kapa
  - Basic / Pro / Enterprise tek tık uygulama
- Paket uygulama çağrısı backend’deki tek template endpoint’ine bağlandı.

## Doğrulama (tamamlandı)
- Backend compile başarı
- Flutter analyze başarı
- Lint hatası yok

---

## 4) Kalan Ana Şablon İşler (Hızlı Canlıya Alma)

### A. Proje Ayrımı (1-2 gün)
Amaç: Kod tabanını cloud ve edge mantıksal olarak ayırmak (ilk aşamada aynı repo içinde).

Hedef klasör şablonu:
- `apps/cloud-backend`
- `apps/edge-backend`
- `apps/cloud-frontend`
- `apps/edge-frontend`
- `packages/contracts` (ortak DTO/API sözleşmeleri)

Not: İlk adımda fiziksel taşıma zor gelirse, mevcut yapıda paket namespace ayrımıyla başlanır.

### B. Çalıştırma Profilleri (1 gün)
Amaç: Tek komutla ayağa kaldırma.

Minimum:
- `docker-compose.cloud.yml`
- `docker-compose.edge.yml`
- veya tek dosyada cloud+edge profilleri

Komut hedefi:
- `docker compose --profile cloud up -d`
- `docker compose --profile edge up -d`

### C. Konfigürasyon Şablonları (1 gün)
Amaç: Her ortamda aynı şekilde ayağa kalkma.

Gerekli env şablonları:
- `.env.cloud.example`
- `.env.edge.example`

İçerik:
- API URL’leri
- restaurant/edge kimlik bilgileri
- feature template başlangıç değeri

### D. Routing Şablonu (2 gün)
Amaç: Personel ve müşteri akışını ayırma.

- Staff uygulamaları -> Edge API
- Customer uygulaması -> Cloud gateway
- Superadmin -> Cloud

### E. Smoke Test Şablonu (1 gün)
Amaç: “çalışıyor mu?” sorusuna hızlı cevap.

Checklist:
1. Restoran oluştur
2. Edge node ekle
3. Paket template uygula
4. Edge node durumunu güncelle
5. UI’de yansımasını doğrula

### F. Deploy Runbook (1 gün)
Amaç: Uygulamayı edge mini PC’ye hızlı kurulum.

İçerik:
- Docker install
- compose up
- env set
- health kontrol
- log alma

---

## 5) 7 Günlük Operasyon Planı (Detaysız, Uygulanabilir)

### Gün 1
- Cloud/edge dosya ve profil şablonlarını oluştur
- Env örneklerini çıkar

### Gün 2
- Cloud backend + frontend container ayaklandır
- Superadmin giriş ve restoran listesi doğrula

### Gün 3
- Edge backend + frontend container ayaklandır (LAN testi)
- Edge node yönetimini canlı test et

### Gün 4
- Routing ayrımını etkinleştir (staff=edge, customer=cloud)
- Paket template akışını uçtan uca test et

### Gün 5
- Smoke test checklist’i otomatikleştir (script)
- İlk mini PC kurulum denemesi

### Gün 6
- Hata düzeltmeleri
- Demo hazırlığı

### Gün 7
- Pilot restoran denemesi
- Go/No-Go değerlendirmesi

---

## 6) Şu Anki Durum

- Durum: **A + B + C + D + E + F maddeleri temel seviyede uygulandı**
- Sonraki adım: **Pilot kurulum ve uçtan uca doğrulama**

---

## 7) Devam Komutları (Bana Yazabileceğin Hazır Promptlar)

- `bu dosyadan devam et, 4. bölümdeki A maddesini uygula`
- `bu dosyadan devam et, docker profile şablonlarını çıkar`
- `bu dosyadan devam et, 7 günlük planın bugünlük kısmını kodla`
- `bu dosyadan devam et, yapılanları güncelle`

---

## 8) Değişiklik Günlüğü

### 2026-05-08
- Doküman oluşturuldu.
- Yapılan backend/frontend şablon işleri işlendi.
- Kalan işler hızlı canlıya alma odaklı sadeleştirildi.
- Monorepo iskelet klasörleri oluşturuldu:
  - `apps/cloud-backend`
  - `apps/edge-backend`
  - `apps/cloud-frontend`
  - `apps/edge-frontend`
  - `packages/contracts`
- Her klasöre geçişi kolaylaştıran başlangıç `README.md` dosyaları eklendi.
- Cloud/Edge compose şablonları eklendi:
  - `docker-compose.cloud.yml`
  - `docker-compose.edge.yml`
- Cloud/Edge env örnek dosyaları eklendi:
  - `.env.cloud.example`
  - `.env.edge.example`
- Routing şablonu uygulandı:
  - Staff path'leri (`/waiter`, `/kitchen`, `/admin`, `/notifications`) -> edge API
  - Customer session token akışı -> cloud API
  - Superadmin ve auth akışı -> cloud API
  - Staff WebSocket bağlantısı -> edge base URL
- Smoke test şablonu script olarak eklendi:
  - `scripts/smoke_cloud_edge.sh`
  - Kullanım: `./scripts/smoke_cloud_edge.sh`
  - Değişkenler: `CLOUD_API_BASE_URL`, `EDGE_API_BASE_URL`, `CLOUD_WEB_URL`
- Edge deploy runbook eklendi:
  - `docs/edge_deploy_runbook.md`
  - İçerik: kurulum, compose çalıştırma, health/smoke, log, update, rollback
