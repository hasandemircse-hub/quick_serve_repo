# Garson el terminali — master plan ve yapılacaklar

**Amaç:** Garson/personel cihazında *olması beklenen* işlevler ile *projedeki gerçek durum* arasındaki farkı tek yerde tutmak; yeni özellik ve borçları buradan takip etmek. Kod tabanını her seferinde taramadan ilerlemek için **kaynak dosya ve endpoint referansları** sabitlendi.

**Son güncelleme:** 2026-05-10  
**İlgili:** [QUICKSERVE_SYSTEM_REFERENCE.md](QUICKSERVE_SYSTEM_REFERENCE.md), [CLAUDE.md](../CLAUDE.md)

---

## Bu belgeyi nasıl kullanmalısınız?

| İhtiyaç | Nereye bakın |
|--------|----------------|
| Ekranda ne var / ne yok | §2 Özet tablo |
| Backend–UI eşlemesi | §3 |
| Yapılacak iş kalemleri | §4 Backlog |
| Yeni tespit (siz veya AI) | §4’e satır ekleyin veya §5 Günlük |
| Durum güncelleme | Backlog’da **Durum** sütununu değiştirin |

**Durum sütunu önerisi:** `yapılmadı` · `devam` · `tamam` · `ertelendi` · `ürün kararı gerekli`

---

## 1. Kod konumları (canonical)

| Bileşen | Yol |
|--------|-----|
| Garson ana ekranı | `packages/shared-frontend/lib/features/waiter/screens/waiter_home_screen.dart` |
| Garson sipariş ekle | `packages/shared-frontend/lib/features/waiter/screens/waiter_session_order_screen.dart` |
| Kasa (oturum sipariş/ödeme) | `packages/shared-frontend/lib/features/cashier/screens/cashier_screen.dart` |
| API sabitleri | `packages/shared-frontend/lib/core/constants/api_constants.dart` |
| Cloud garson API | `apps/cloud-backend/.../controller/WaiterController.java` |
| Edge personel (ayrı ürün hattı) | `apps/edge-frontend`, `apps/edge-backend` — cloud Flutter ile birebir aynı değil; edge için ayrı UAT |

---

## 2. Beklenen vs mevcut (özet)

Tipik el terminalinde garson için düşünülen başlıklar ve **cloud shared-frontend garson ekranı** özelinde durum:

| Alan | Beklenti | Cloud garson ekranı (`WaiterHomeScreen`) |
|------|-----------|----------------------------------------|
| Masa listesi / doluluk | Var | **Var** — `/waiter/tables` |
| Çağrı (garson/hesap vb.) | Var | **Var** — liste, assign, resolve |
| Hazır sipariş → teslim | Var | **Var** — `/waiter/orders`, deliver |
| Oturumu kapatma | Var | **Var** — `/waiter/sessions/{id}/close` + sebep |
| Gerçek zamanlı | İstenir | **Kısmen** — sipariş/çağrı + **masa** WS; masa listesi olayda yalnız `GET /waiter/tables` ile yenilenir |
| Masadan sipariş girme | Sık beklenir | **Var** — dolu masada **Sipariş ekle** → `WaiterSessionOrderScreen` (`GET /waiter/menu`, `POST /waiter/sessions/{id}/orders`) |
| Oturum adisyonu / sipariş detayı | Sık beklenir | **Kısmen** — **Masa özeti** diyaloğu (`financial-summary`) + **Kasa** deep link (`/cashier?sessionId=`) |
| Ödeme (nakit/POS/bölme) | İşletmeye göre | **Kısmen** — **Hızlı nakit** (`POST .../payments/cash`, dağıtım boş → oturum); POS/bölüşüm **Kasa** |
| HEAD_WAITER ayrı UI | İsteğe bağlı | **Kısmen** — AppBar **Mutfak** kısayolu (`/kitchen`); ayrı rol ekranı yok |

**Sonuç:** Garson ekranı masa operasyonu + çağrı + teslim + **masadan sipariş** + özet; tam adisyon/ödeme hâlâ **Kasa** üzerinden.

---

## 3. WaiterController ↔ UI eşlemesi (cloud)

| Endpoint | Garson home | Kasa / diğer |
|----------|-------------|------|
| `GET /waiter/tables` | Kullanılıyor | — |
| `GET /waiter/menu` | Sipariş ekle ekranı | — |
| `GET /waiter/calls` | Kullanılıyor | — |
| `POST /waiter/calls/{id}/assign` | Kullanılıyor | — |
| `POST /waiter/calls/{id}/resolve` | Kullanılıyor | — |
| `GET /waiter/orders` | Kullanılıyor | — |
| `POST /waiter/orders/{id}/deliver` | Kullanılıyor | — |
| `POST /waiter/sessions/{id}/close` | Kullanılıyor | — |
| `POST /waiter/sessions/{id}/orders` | Sipariş ekle ekranı | — |
| `GET /waiter/sessions/{id}/orders` | — | Kullanılıyor |
| `GET /waiter/sessions/{id}/financial-summary` | Masa özeti diyaloğu | Kullanılıyor |
| `GET /waiter/sessions/{id}/payments` | — | Kullanılıyor |
| `POST /waiter/sessions/{id}/payments/cash` | Hızlı nakit diyaloğu | Kullanılıyor |
| `POST .../payments/pos/init` | — | Kullanılıyor |
| `POST .../payments/pos/{id}/confirm` | — | Kullanılıyor |
| `POST .../payments/pos/{id}/cancel` | — | Kullanılıyor |
| `GET .../payments/pos/{id}/status` | — | Kullanılıyor |
| `POST /waiter/payments/cash` (+ `X-Session-Token`) | — | İhtiyaç halinde (müşteri oturumu header’lı akış; kasa ekranı öncelikli session path) |

*Not:* Edge tarafında aynı endpoint seti birebir olmayabilir; edge için `docs/cloud_edge_master_delivery_plan.md` ve edge UAT ile doğrulanmalı.

---

## 4. Backlog — tespit edilen eksikler ve kararlar

Aşağıdaki satırlar **ürün/teknik borç** takibi içindir. İş bittiğinde **Durum** = `tamam` yapın ve isteğe bağlı **Not**’a PR veya commit ref ekleyin.

| ID | Başlık | Özet kabul / not | Durum | Sahip |
|----|--------|------------------|-------|-------|
| WT-01 | Garsondan sipariş girişi | `GET /waiter/menu` + `POST /waiter/sessions/{id}/orders`; UI: `/waiter/session-order` | tamam | |
| WT-02 | Adisyon önizleme (garson home) | Masa alt sayfası: özet diyaloğu + `context.go(/cashier?sessionId=)` | tamam | |
| WT-03 | Tek cihazda ödeme | **Hızlı nakit** (masa alt menüsü); POS/tam dağıtım kasada | kısmi | |
| WT-04 | HEAD_WAITER farkılaştırma | **Mutfak** ikonu; geniş yetki/ekran ürün kararı | kısmi | |
| WT-05 | VALET / diğer roller | `CLAUDE.md` bilinen eksik; garson dokümanı dışında global rol planına bağlı | ertelendi | |
| WT-06 | WebSocket tek kaynak | Garson: **masa** topic + hedefli masa yenileme; çağrıda hâlâ tam `_loadData` | kısmi | |

---

## 5. Günlük / yeni tespitler

Buraya kısa not düşün (tarih + cümle). Periyodik olarak §4 backlog’a **ID** ile taşıyın.

| Tarih | Not |
|-------|-----|
| 2026-05-08 | İlk sürüm: garson home vs kasa ayrımı ve WaiterController eşlemesi yazıldı. |
| 2026-05-09 | WT-01/02: garson menü+sipariş, masa özeti, kasa deep link, `CashierScreen(initialSessionId)`. |
| 2026-05-10 | WT-03/04/06 kısmi: hızlı nakit, HEAD_WAITER→mutfak, masa WS + `_loadTablesOnly`. |

---

## 6. Değişiklik günlüğü (belge)

| Tarih | Değişiklik |
|-------|------------|
| 2026-05-08 | Belge oluşturuldu; WT-01–WT-06 backlog tanımlandı. |
| 2026-05-09 | WT-01 ve WT-02 tamamlandı; tablolar güncellendi. |
| 2026-05-10 | Hızlı nakit, mutfak kısayolu, garson masa WebSocket davranışı dokümante edildi. |

---

*Bu belge `docs/waiter_terminal_master_plan.md` yolundadır. AI veya geliştirici görev alırken önce bu dosyayı okuyup backlog’u güncellemelidir.*
