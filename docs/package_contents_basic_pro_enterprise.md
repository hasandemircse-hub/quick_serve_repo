# Paket İçerik Dokümanı (Basic / Pro / Enterprise)

Bu doküman satış ve onboarding ekipleri için QuickServe paket kapsamını standardize eder.

## 1) Paket Tanım Prensibi

- Paket kapsamı teknik olarak feature-flag ile yönetilir.
- Mevcut flag seti:
  - `POS`
  - `BILL_PRINTING`
  - `TABLE_PAYMENT`
  - `MENU_IMAGES`
  - `CUSTOMER_SPLIT_BILL`

## 2) Paket Matrisi

| Özellik | Basic | Pro | Enterprise |
|---|---|---|---|
| POS Cihaz Entegrasyonu (`POS`) | Kapalı | Açık | Açık |
| Adisyon/Yazdırma (`BILL_PRINTING`) | Açık | Açık | Açık |
| Masada Ödeme (`TABLE_PAYMENT`) | Kapalı | Açık | Açık |
| Menü Görselleri (`MENU_IMAGES`) | Kapalı | Açık | Açık |
| Müşteri Hesap Bölme (`CUSTOMER_SPLIT_BILL`) | Kapalı | Açık | Açık |

## 3) Paketlerin Operasyonel Konumlandırması

### Basic
- Hedef profil: küçük/tek şubeli restoran, düşük operasyon karmaşıklığı
- Değer önerisi: temel dijital sipariş + adisyon altyapısı
- Sınırlar: POS/masa ödeme/split bill yok

### Pro
- Hedef profil: yoğun servis alan restoran, operasyonel hız ihtiyacı yüksek işletme
- Değer önerisi: POS + masa ödeme + görselli menü + split bill ile tam servis akışı
- Sınırlar: enterprise destek/SLA kapsamı ayrı ticari başlıkta ele alınır

### Enterprise
- Hedef profil: çok şubeli veya yüksek SLA talebi olan işletme
- Değer önerisi: Pro özellik seti + kurumsal operasyon süreçleriyle birlikte ölçekli kullanım
- Not: teknik feature set şu an Pro ile aynıdır; fiyat/SLA/destek farkı ticari pakette yönetilir

## 4) Aktivasyon ve Geçiş Süreci

1. Superadmin panelinden restoran seçilir.
2. `Lisans / Paket` ekranından `BASIC / PRO / ENTERPRISE` şablonu uygulanır.
3. Feature-flag’ler restoran bazında güncellenir.
4. UI refresh sonrası yeni paket kapsamı görünür olur.

## 5) Satış Öncesi Açık Notlar

- Enterprise paketinde ek teknik capability gerekiyorsa yeni feature-flag ile genişletilmelidir.
- Paket yükseltme/düşürme aksiyonları audit log ile takip edilmelidir.
- Fiyatlandırma bu dokümanın dışında, `3.7.2` kapsamındaki maliyet dokümanı ile birleştirilmelidir.
