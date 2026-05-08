# UAT Checklist (Restoran Operasyonu)

Bu checklist, QuickServe cloud+edge pilotunda restoran operasyonunun kabul testini standardize eder.

## 1) Test Ön Koşulları

- Cloud stack çalışıyor (`docker-compose.cloud.yml`)
- Edge stack çalışıyor (`docker-compose.edge.yml` veya deploy compose)
- Test restoranı ve personel kullanıcıları hazır
- En az 1 adet test masası ve test menü ürünü mevcut

## 2) Test Rolleri

- Superadmin
- Restoran Admini
- Garson
- Mutfak
- Kasa
- Müşteri (QR)

## 3) Kabul Kriteri Kuralı

- Her adım için `PASS/FAIL` işaretlenir.
- Kritik adımlarda (K) `FAIL` varsa UAT geçmez.
- UAT geçiş koşulu:
  - Kritik adımların tamamı `PASS`
  - Toplam adımların en az `%95`i `PASS`

## 4) Senaryo Adımları

Format:
- `[K]` kritik adım
- `Beklenen` alanı sağlanmıyorsa `FAIL`

### A) Superadmin Operasyonları

1. `[K]` Superadmin login
   - Beklenen: `/superadmin` ekranı açılır
   - Sonuç: `PASS / FAIL`

2. Restoran listesi + fleet health görünümü
   - Beklenen: restoranlar ve fleet metrikleri yüklenir
   - Sonuç: `PASS / FAIL`

3. Operasyon logları görüntüleme
   - Beklenen: restoran bazlı loglar listelenir/sayfalanır
   - Sonuç: `PASS / FAIL`

### B) Restoran Admin Operasyonları

4. `[K]` Admin login (edge-first)
   - Beklenen: edge erişiminde hızlı login, edge yoksa cloud fallback
   - Sonuç: `PASS / FAIL`

5. Menü kategorisi + ürün CRUD
   - Beklenen: ekle/güncelle/sil aksiyonları UI’da anında görünür
   - Sonuç: `PASS / FAIL`

6. Masa grupları + masa CRUD
   - Beklenen: grup atama ve QR işlemleri sorunsuz
   - Sonuç: `PASS / FAIL`

### C) Garson + Mutfak + Kasa Operasyonları

7. `[K]` Garson ekranı masa/call/order sekmeleri
   - Beklenen: veriler yüklenir, refresh çalışır
   - Sonuç: `PASS / FAIL`

8. `[K]` Mutfak sipariş akışı
   - Beklenen: `PENDING -> PREPARING -> READY` akışı çalışır
   - Sonuç: `PASS / FAIL`

9. `[K]` Garson teslim akışı
   - Beklenen: READY sipariş teslim edildiye geçer/listeden düşer
   - Sonuç: `PASS / FAIL`

10. `[K]` Kasa tahsilat akışı (nakit)
    - Beklenen: ödeme kaydı oluşur, kalan bakiye düşer
    - Sonuç: `PASS / FAIL`

11. POS ödeme akışı (aktif restoran için)
    - Beklenen: init/confirm/cancel adımları beklenen sonuçla tamamlanır
    - Sonuç: `PASS / FAIL`

### D) Müşteri Akışı

12. `[K]` QR ile oturum başlatma
    - Beklenen: müşteri menüye ulaşır
    - Sonuç: `PASS / FAIL`

13. Sipariş oluşturma
    - Beklenen: sipariş garson/mutfak tarafında görünür
    - Sonuç: `PASS / FAIL`

14. Ödeme ekranı ve ödeme sonrası durum
    - Beklenen: ödeme sonucu ve sipariş durumu doğru güncellenir
    - Sonuç: `PASS / FAIL`

### E) Offline + Sync Davranışı

15. `[K]` Cloud kapalıyken edge personel işlemleri
    - Beklenen: waiter/kitchen/cashier kritik aksiyonları çalışır
    - Sonuç: `PASS / FAIL`

16. Offline uyarı + sync lag göstergesi
    - Beklenen: offline banner ve sync gecikme bandı görünür
    - Sonuç: `PASS / FAIL`

17. `[K]` Cloud geri geldikten sonra sync toparlanma
    - Beklenen: outbox pending/retry sıfıra yakınsar, kritik dead oluşmaz
    - Sonuç: `PASS / FAIL`

## 5) UAT Sonuç Özeti

- Test tarihi:
- Test ortamı:
- Toplam adım:
- PASS:
- FAIL:
- Kritik FAIL var mı?: `Evet / Hayır`
- Nihai karar: `GO / NO-GO`

## 6) GO/NO-GO Karar Kuralı

- GO:
  - Kritik adımların tamamı PASS
  - Bloklayıcı veri kaybı veya ödeme hatası yok
- NO-GO:
  - Kritik adımlardan en az biri FAIL
  - Offline->online toparlanmada kuyruk dead-letter birikimi var
