# POS Saglayici Entegrasyon Kontrol Listesi

Bu dokuman, mevcut POS cihazini QuickServe kasadan tetikleyebilmek icin saglayicidan alinmasi gereken resmi/teknik bilgileri listeler.

## 1) Cihaz Bilgisi
- Marka
- Model
- Banka uygulamasi/versiyonu
- Terminal ID / Merchant ID

## 2) Teknik Yetkinlik Sorulari
- Dis sistemden tutar tetikleme destekleniyor mu?
- Entegrasyon tipi nedir? (SDK / TCP / ECR / Intent / Local Service)
- Islem sonucu nasil donuyor? (sync response / webhook / polling)
- Provider transaction id ve referans alanlari neler?
- Timeout ve iptal kodlari neler?

## 3) Guvenlik ve Dogrulama
- Mesaj imzalama/HMAC var mi?
- Source IP allowlist gerekiyor mu?
- Test ve prod ortam endpointleri ayri mi?

## 4) Operasyon ve Mutabakat
- Gun sonu rapor dosyasi/endpoint var mi?
- Islem no ile sorgulama endpointi var mi?
- Cihazda basarili olup sistemde eksik kalan islemler nasil uzlastirilir?

## 5) QuickServe Uygulama Notu
- QuickServe tarafinda POS odemesi iki adimda ilerler:
  1. `POST /waiter/sessions/{sessionId}/payments/pos/init`
  2. `POST /waiter/sessions/{sessionId}/payments/pos/{posIntentId}/confirm`
- Cihazdan otomatik sonuc alinmiyorsa kasiyer ekraninda manuel "Basarili/Basarisiz" onayi ile fallback kullanilir.

