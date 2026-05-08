# Kurulum Süresi SLA ve Destek Süreçleri

Bu doküman QuickServe cloud+edge kurulum hedef sürelerini ve destek operasyon modelini standartlaştırır.

## 1) SLA Seviyeleri

### 1.1 İlk Kurulum SLA (Yeni Restoran)

- Hedef süre (standart): `T+1 iş günü`
- Hedef süre (hızlı kurulum): `T+4 saat` (ön gereksinimler hazırsa)
- Kapsam:
  - cloud restoran açılışı
  - edge node provisioning
  - paket aktivasyonu
  - temel smoke/UAT adımları

### 1.2 Incident Yanıt SLA

- P1 (operasyon durdu): ilk yanıt `15 dk`, geçici çözüm `1 saat`
- P2 (kritik fonksiyon bozuk): ilk yanıt `30 dk`, geçici çözüm `4 saat`
- P3 (kısmi bozulma): ilk yanıt `4 saat`, çözüm `1 iş günü`
- P4 (iyileştirme/istek): ilk yanıt `1 iş günü`, planlı sürümde ele alınır

## 2) Destek Kanalları

- Birincil: ticket sistemi (önerilen)
- İkincil: WhatsApp/telefon acil hattı (P1/P2)
- Üçüncül: e-posta (P3/P4)

Kural:
- Her bildirim ticket'a dönüştürülür.
- Ticket numarası olmadan incident kapatılmaz.

## 3) Destek Süreci (L1 -> L2 -> L3)

### L1 (Operasyon)

- Servis ayakta mı (`docker compose ps`)
- Health endpoint kontrolü
- Temel log kontrolü
- Runbook adımlarını uygula

### L2 (Uygulama)

- Cloud/edge konfigürasyon doğrulama
- Sync kuyruk ve lag analizi
- Paket/feature flag doğrulama
- Kontrollü restart/rollback

### L3 (Mühendislik)

- Kod seviyesinde root-cause analizi
- Hotfix/patch hazırlığı
- Kalıcı düzeltme ve postmortem

## 4) Kurulum Adım Süre Bütçesi (Hedef)

- Cloud restoran tanımı + admin kullanıcı: `20 dk`
- Edge cihaz hazırlığı + env doğrulama: `40 dk`
- Edge deploy + enrollment: `30 dk`
- Smoke + UAT mini set: `30 dk`
- Toplam hedef: `120 dk` (2 saat)

## 5) Escalation Kuralı

- P1:
  - 15 dk içinde çözüm yoksa L2’ye
  - 30 dk içinde çözüm yoksa L3’e
- P2:
  - 30 dk içinde çözüm yoksa L2’ye
  - 2 saat içinde çözüm yoksa L3’e

## 6) Kapanış Kriteri

Incident ancak şu koşullarda kapanır:

- Etki alanı doğrulandı (restoran tarafından)
- Geçici veya kalıcı çözüm uygulandı
- Ticket'a aksiyon özeti yazıldı
- Gerekirse runbook güncellendi

## 7) Operasyonel KPI Önerileri

- MTTA (ilk yanıt süresi)
- MTTR (çözüm süresi)
- P1/P2 aylık incident adedi
- İlk kurulum başarı oranı
- İlk kurulum ortalama tamamlanma süresi
