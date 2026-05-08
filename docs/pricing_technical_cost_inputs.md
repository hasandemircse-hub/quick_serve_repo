# Fiyatlandırma İçin Teknik Maliyet Dökümü

Bu doküman, Basic/Pro/Enterprise paket fiyatlandırmasında kullanılacak teknik maliyet girdilerini standardize eder.

## 1) Amaç ve Kapsam

- Amaç: satış fiyatını belirlerken teknik maliyet bileşenlerini görünür ve ölçülebilir hale getirmek.
- Kapsam: cloud + edge çalıştırma maliyeti, operasyon maliyeti, destek maliyeti, entegrasyon maliyeti.

## 2) Maliyet Bileşenleri

### A) Cloud Altyapı Maliyeti (Aylık)

- Compute (backend container + ek servisler)
- Database (PostgreSQL disk + IOPS)
- Ağ/traffic (egress)
- Monitoring stack (Prometheus/Grafana/Sentry benzeri)
- Backup saklama

Formül:

`CloudToplam = Compute + DB + Traffic + Monitoring + Backup`

### B) Edge Runtime Maliyeti (Aylık)

- Edge cihaz amortizasyonu (mini PC veya mevcut donanım)
- Elektrik + ağ payı
- Edge bakım/güncelleme operasyon zamanı

Formül:

`EdgeToplam = DonanimAmortisman + ElektrikAg + EdgeOps`

### C) Destek ve Operasyon Maliyeti (Aylık)

- L1/L2 destek personel süresi
- Incident müdahale süresi
- Uzak güncelleme/rollback operasyonları

Formül:

`DestekToplam = DestekSaat * SaatlikMaliyet + IncidentPayi`

### D) Özellik Bazlı Değişken Maliyet

- POS provider entegrasyon/işlem maliyetleri
- SMS bildirim maliyeti
- Gelecekte eklenecek 3rd-party servis lisansları

Formül:

`DegiskenToplam = POS + SMS + UcuncuParti`

## 3) Paket Bazlı Maliyet Etkisi

### Basic

- Düşük değişken maliyet
- POS ve masada ödeme kapalı olduğu için işlem karmaşıklığı düşük
- Destek yükü düşük-orta

### Pro

- POS + masada ödeme + split bill aktif
- Değişken maliyet ve destek yükü artar
- Operasyonel izleme ihtiyacı daha yüksek

### Enterprise

- Pro özellik seti + kurumsal SLA beklentisi
- Destek ve operasyon maliyet çarpanı en yüksek segment

## 4) Fiyatlandırma Hesap Şablonu

Önerilen yaklaşım:

`PaketMaliyeti = CloudToplam + EdgeToplam + DestekToplam + DegiskenToplam`

`ListeFiyat = PaketMaliyeti * HedefBrutMarjKatsayisi`

Ek not:

- Enterprise için ayrı `SLA_Carpani` uygulanmalı:
  - `EnterpriseFiyat = ListeFiyat * SLA_Carpani`

## 5) Gerekli Veri Girdileri (Satış/Finans ile Netleşecek)

- Cloud aylık fatura kalemleri (compute/db/traffic/backup)
- Edge donanım birim maliyeti ve amortizasyon süresi
- Destek ekibi saatlik maliyet ve ortalama ticket süresi
- POS/SMS sağlayıcı birim ücretleri
- Hedef brüt marj oranı (paket bazlı)

## 6) Karar Çıktısı

Bu doküman tamamlandığında aşağıdaki çıktılar üretilir:

- Basic/Pro/Enterprise için minimum sürdürülebilir taban maliyet
- Paket bazlı önerilen liste fiyat aralığı
- SLA veya ek entegrasyonların fiyat etkisi
