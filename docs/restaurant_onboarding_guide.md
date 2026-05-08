# Restoran Onboarding Rehberi

Bu rehber yeni restoranın QuickServe cloud+edge kurulumunu operasyona hazır hale getirmek için adım adım uygulanır.

## 1) Onboarding Öncesi Hazırlık

### Gerekli Bilgiler

- Restoran adı, adresi, iletişim kişisi
- Operasyon saatleri
- Kullanılacak cihazlar:
  - edge mini PC veya mevcut donanım
  - yazıcı modeli
  - POS cihaz/provider bilgisi
- Ağ bilgisi:
  - LAN IP planı
  - internet erişimi

### Hesap Açılışı

- Superadmin panelinde restoran kaydı açılır
- İlk admin kullanıcı oluşturulur
- Paket (Basic/Pro/Enterprise) seçilir

## 2) Teknik Kurulum Akışı

1. Edge cihaz üzerinde Docker ve Compose hazırla
2. Repo çek ve `.env.edge` dosyasını oluştur
3. Gerekli env alanlarını doldur:
   - `EDGE_NODE_ID`
   - `EDGE_RESTAURANT_ID`
   - `EDGE_CLOUD_BASE_URL`
   - `EDGE_ENROLLMENT_TOKEN`
   - `EDGE_SQLITE_PATH`
4. Edge deploy çalıştır:
   - lokal: `docker compose --env-file .env.edge -f docker-compose.edge.yml up -d`
   - release: `./scripts/deploy_edge_release.sh --tag <TAG>`

## 3) İlk Doğrulama (Go-Live Öncesi)

- Health kontrolleri:
  - cloud: `/api/actuator/health`
  - edge: `/api/actuator/health`
- Entegrasyon smoke:
  - `./scripts/smoke_cloud_edge.sh`
- UAT checklist:
  - `docs/uat_checklist_restaurant_operations.md`

## 4) Operasyon Aktivasyonu

- Garson, mutfak, kasa kullanıcıları açılır
- Menü kategorileri ve ürünler eklenir
- Masalar ve QR kodları hazırlanır
- En az 1 test siparişi + 1 test ödeme ile canlı öncesi prova yapılır

## 5) Eğitim Planı (Kısa)

- Garson: masa/sipariş/call/teslim akışı
- Mutfak: hazırlama/hazır akışı
- Kasa: tahsilat + adisyon
- Admin: menü/masa/personel yönetimi

## 6) İlk 7 Gün Destek Planı

- Günlük sağlık kontrolü (ilk hafta)
- Kritik incident için hızlı kanal paylaşımı
- Gerekirse paket/feature ayarı revizyonu

## 7) Başarılı Onboarding Kriteri

Onboarding tamamlandı sayılması için:

- Teknik kurulum tamam ve health PASS
- UAT kritik adımlar PASS
- Restoran ekibi temel operasyonları bağımsız yürütebiliyor
- İlk canlı gün sonunda kritik açık incident yok
