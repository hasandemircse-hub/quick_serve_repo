# POS Pilot Mutabakat Runbook

Bu runbook, pilot subede POS ile alinan odemelerin QuickServe kayitlariyla gun sonu tutarliligini kontrol etmek icin kullanilir.

## Pilot Kapsami
- 1 sube
- 1-2 kasa personeli
- En az 30 POS odemesi (basarili + basarisiz + timeout)

## Kontrol Adimlari
1. Kasa ekranindan POS odemelerini alin (`POS Kart` yontemi).
2. Her islemde POS slip/txn no not edin.
3. Gun sonunda QuickServe odeme listesinde ilgili session/masa odemelerini filtreleyin.
4. Asagidaki alanlari birebir karsilastirin:
   - Tutar
   - Islem zamani
   - Durum (`COMPLETED/FAILED/TIMEOUT`)
   - `providerTxnId` (varsa)

## Uyuşmazlık Kurallari
- POS basarili, QuickServe `PENDING/TIMEOUT`:
  - `confirm` endpointiyle manuel kesinlestirme yapin.
- QuickServe `COMPLETED`, POS red:
  - Islem kaydini `FAILED` olarak guncelleyin ve not dusun.
- Ayni idempotency key ile ikinci odeme olusmus mu:
  - Olusmamalidir. Varsa kritik bug olarak kayit acin.

## Basari Kriterleri
- Cift kayit: 0
- Toplam tutar farki: 0.00
- Timeout sonrasinda manuel toparlama suresi: <= 2 dakika

