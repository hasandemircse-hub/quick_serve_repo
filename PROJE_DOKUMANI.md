# QuickServe (v0.0.1) — Proje Akış Dokümantasyonu-16/04/2026

> Oluşturulma: 2026-04-16  
> Kapsam: Flutter frontend + Spring Boot backend — tüm roller için tam akış analizi + eksik implementasyon raporu

---

## İçindekiler

1. [Mimari Özet](#1-mimari-özet)
2. [Roller ve Yetki Hiyerarşisi](#2-roller-ve-yetki-hiyerarşisi)
3. [Kimlik Doğrulama Akışı](#3-kimlik-doğrulama-akışı)
4. [Müşteri Akışı](#4-müşteri-akışı)
5. [Garson (WAITER / HEAD_WAITER) Akışı](#5-garson-waiter--head_waiter-akışı)
6. [Mutfak (CHEF) Akışı](#6-mutfak-chef-akışı)
7. [Restoran Admin Akışı](#7-restoran-admin-akışı)
8. [Superadmin Akışı](#8-superadmin-akışı)
9. [Bildirim ve WebSocket Mimarisi](#9-bildirim-ve-websocket-mimarisi)
10. [Eksiklik ve Akış Kırıklıkları Raporu](#10-eksiklik-ve-akış-kırıklıkları-raporu)

---

## 1. Mimari Özet

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Uygulaması                      │
│  GoRouter · Riverpod · Dio · STOMP (stomp_dart_client)  │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP / WebSocket (SockJS)
┌──────────────────────────▼──────────────────────────────┐
│              Spring Boot Backend (:8080)                  │
│  /api/**  ·  Spring Security JWT  ·  JPA / Hibernate    │
│  Swagger: /swagger-ui.html                               │
└──────────────────────────┬──────────────────────────────┘
                           │ JPA
┌──────────────────────────▼──────────────────────────────┐
│                  PostgreSQL Veritabanı                    │
└─────────────────────────────────────────────────────────┘
```

### Kimlik Doğrulama Mekanizmaları

| Taraf    | Mekanizma              | Header / Storage               |
|----------|------------------------|-------------------------------|
| Personel | JWT Bearer Token       | `Authorization: Bearer <token>` |
| Müşteri  | Session Token (QR ile) | `X-Session-Token: <token>`    |

---

## 2. Roller ve Yetki Hiyerarşisi

```mermaid
graph TD
    SA["SUPERADMIN<br/>Seviye 3"]
    RA["RESTAURANT_ADMIN<br/>Seviye 2"]
    HW["HEAD_WAITER<br/>Seviye 1"]
    W["WAITER<br/>Seviye 1"]
    C["CHEF<br/>Seviye 1"]
    V["VALET<br/>Seviye 1"]
    CU["MÜŞTERİ<br/>(QR Token)"]

    SA -->|"yönetir"| RA
    RA -->|"yönetir"| HW
    RA -->|"yönetir"| W
    RA -->|"yönetir"| C
    RA -->|"yönetir"| V

    SA -->|"/superadmin"| SASC["Superadmin Ekranı"]
    RA -->|"/admin"| ADSC["Admin Dashboard"]
    HW -->|"/waiter"| WSC["Garson Ekranı"]
    W  -->|"/waiter"| WSC
    C  -->|"/kitchen"| KSC["Mutfak Ekranı"]
    V  -->|"/waiter ⚠️"| WSC
    CU -->|"/scan → /menu"| MSC["Müşteri Menü"]
```

> ⚠️ `VALET` rolü şu an garson ekranına yönlendiriyor. Ayrı ekranı yok.  
> ⚠️ `HEAD_WAITER` ile `WAITER` arasında UI'da hiçbir fark yok.

### Rota Tablosu

| Rota | Erişim | Ekran |
|------|--------|-------|
| `/scan` | Herkese açık | QR Okuyucu |
| `/scan/:qrToken` | Herkese açık | Menü (QR token ile) |
| `/menu` | Herkese açık | Menü (token olmadan — yetki hatası verir) |
| `/cart` | Herkese açık | Sepet ⚠️ (artık kullanılmıyor) |
| `/payment` | Müşteri | Ödeme |
| `/review` | Müşteri | Değerlendirme |
| `/login` | Herkese açık | Personel Girişi |
| `/waiter` | WAITER / HEAD_WAITER / VALET | Garson Paneli |
| `/kitchen` | CHEF | Mutfak Paneli |
| `/admin` | RESTAURANT_ADMIN | Admin Dashboard |
| `/superadmin` | SUPERADMIN | Superadmin Paneli |

---

## 3. Kimlik Doğrulama Akışı

### 3a. Personel Girişi (JWT)

```mermaid
flowchart TD
    A([Uygulama Açılır]) --> B{LocalStorage'da\nJWT var mı?}
    B -->|Evet| C{Token geçerli mi?\nRole ne?}
    B -->|Hayır| SCAN["/scan — QR Okuyucu"]
    C -->|SUPERADMIN| SA["/superadmin"]
    C -->|RESTAURANT_ADMIN| AD["/admin"]
    C -->|WAITER / HEAD_WAITER| WA["/waiter"]
    C -->|CHEF| KI["/kitchen"]
    C -->|VALET| WA2["/waiter ⚠️"]
    C -->|Geçersiz/Süresi dolmuş| LOGIN["/login"]

    LOGIN --> F[Kullanıcı adı + şifre girer]
    F --> G["POST /auth/login"]
    G -->|200 OK| H["JWT + userData saklanır\n(LocalStorage)"]
    H --> I[authProvider güncellenir]
    I --> J[GoRouter redirect tetiklenir]
    J --> C
    G -->|401| K[Hata gösterilir]
    K --> F
```

### 3b. Çıkış

```mermaid
flowchart LR
    A[Çıkış Butonu] --> B["authProvider.logout()"]
    B --> C["LocalStorage.clearToken()\nLocalStorage.clearUserInfo()"]
    C --> D[GoRouter → /login]
```

---

## 4. Müşteri Akışı

### 4a. QR Okutma → Menüye Erişim

```mermaid
flowchart TD
    A([Müşteri masaya oturur]) --> B[Telefon kamerasını açar]
    B --> C["QrScanScreen — /scan\nmobile_scanner kütüphanesi"]
    C --> D{QR kod algılandı mı?}
    D -->|Hayır — bekleniyor| C
    D -->|Evet — URL ayrıştırılıyor| E{URL formatı\n/scan/:token mi?}
    E -->|Hayır — /staff/login| LGN["/login ekranına git"]
    E -->|Evet| F["context.go('/scan/:qrToken')"]
    F --> G["MenuScreen(qrToken: token)"]
    G --> H["GET /customer/scan/:qrToken"]
    H -->|200 SessionResponse| I["X-Session-Token LocalStorage'a kaydedilir\nRestaurant + Masa bilgisi yüklenir"]
    I --> J["GET /customer/menu\n(X-Session-Token ile)"]
    J --> K["Menü kategorilere göre render edilir"]
    H -->|Hata: Geçersiz QR| ERR["Hata snackbar\n→ /scan"]

    style A fill:#e8f5e9
    style K fill:#e3f2fd
```

### 4b. Menü Ekranı — Tam Akış

```mermaid
flowchart TD
    MENU(["Menü Ekranı\n(/scan/:qrToken)"])
    MENU --> CAT["Kategori Barı\n(yatay scroll)"]
    CAT --> SRCH["🔍 Arama Butonu\n(sağ uçta, genişler)"]
    MENU --> GRID["Ürün Grid'i\n(_ProductCard)"]

    GRID --> CARD{"Ürün Kartı"}
    CARD -->|"isAvailable = false"| SOLD["'Tükendi' overlay\n(tıklanamaz)"]
    CARD -->|"Kullanılabilir"| ADD["+ Butonu\n(CartNotifier.add)"]
    ADD --> QTY["Inline miktar stepper\n(- qty +)"]
    QTY -->|"0'a düşürülürse"| RM["Sepetten çıkarılır"]

    MENU --> CARTBAR{Sepette ürün var mı?}
    CARTBAR -->|Evet| CB["Floating Cart Bar\n(alt, 3 buton)"]
    CARTBAR -->|Hayır| BTM["Alt Bar\n(Siparişler | Garson | Hesap)"]
    
    CB --> ORD["Siparişler butonu\n→ _OrdersSheet"]
    CB --> WAI["Garson Çağır butonu\n→ POST /customer/calls/waiter"]
    CB --> BILL["Hesap İste butonu\n→ POST /customer/calls/bill\n→ /payment"]
    
    BTM --> ORDSH["Siparişler butonu\n→ _OrdersSheet"]
    BTM --> WAISH["Garson Çağır\n→ POST /customer/calls/waiter"]
    BTM --> BILLSH["Hesap İste\n→ POST /customer/calls/bill\n→ /payment"]

    CB --> SHEET["Sepet ikonuna tıkla\n→ _CartSheet açılır"]
    SHEET --> NOTE["Her ürün için not ekle"]
    SHEET --> CONFIRM["'Siparişi Onayla' butonu"]
    CONFIRM --> POST["POST /customer/orders\n{items: [{menuItemId, quantity, note}]}"]
    POST -->|"201"| CLEAR["Sepet temizlenir\nHaptic feedback (heavy)"]
    POST -->|Hata| ERRS["Snackbar hata mesajı"]

    ORDSH --> POLLORD["GET /customer/orders\n(15 saniyede bir polling)"]
    POLLORD --> ORDLIST["Sipariş listesi + durum badge'leri"]
```

### 4c. Sipariş Durum Takibi (Müşteri Tarafı)

```mermaid
flowchart LR
    A["Sipariş Verildi\nPENDING"] -->|"Mutfak: Hazırlamaya Başla"| B["PREPARING"]
    B -->|"Mutfak: Hazır"| C["READY"]
    C -->|"Garson: Teslim Et"| D["DELIVERED"]
    A -->|"Mutfak/Admin: İptal"| E["CANCELLED"]

    subgraph Müşteri_Görünümü["Müşteri Görünümü — _OrdersSheet"]
        A1["🟡 Bekleniyor"]
        B1["🔵 Hazırlanıyor"]
        C1["🟢 Hazır"]
        D1["⚫ Teslim Edildi"]
    end

    A --> A1
    B --> B1
    C --> C1
    D --> D1
```

> ⚠️ **Akış Kırıklığı**: Müşteri sipariş durumunu 15 saniyede bir polling ile görüyor. WebSocket ile anlık bildirim gelmiyor (bkz. Bölüm 10, Sorun #3).

### 4d. Ödeme Akışı

```mermaid
flowchart TD
    A["Hesap İste butonuna basılır"] --> B["POST /customer/calls/bill\n(Garsona bildirim gider)"]
    B --> C["→ /payment ekranı"]
    C --> D["GET /customer/orders\n(cancelled olmayanların toplamı hesaplanır)"]
    D --> E["Özet Kart: Yemek Tutarı"]
    E --> F{Bahşiş seçimi}
    F --> G["0% / 5% / 10% / 15% / 20%"]
    G --> H{Ödeme Yöntemi}
    H -->|"CASH / OTHER"| I["'Ödeme İste' butonu"]
    H -->|"CREDIT_CARD / DEBIT_CARD"| J["'Kartla Öde' butonu"]

    I --> K["Snackbar: Garsonunuz gelecek"]
    K --> L["→ /review ekranı"]

    J --> M["POST /customer/payments/iyzico/init\n{method, amount, tipAmount}"]
    M -->|"200 {paymentUrl: '...'}"| N["⚠️ TODO: url_launcher ile aç\n(ŞU AN ÇALIŞMIYOR)"]
    M -->|Hata| ERR["Snackbar hata"]

    subgraph Hesabı_Böl["Hesabı Böl Dialog"]
        SB1["2 kişi — kişi başı tutar"]
        SB2["3 kişi — kişi başı tutar"]
        SB3["4 kişi"]
        SB4["5 kişi"]
        SB5["⚠️ Yalnızca gösterim — API çağrısı yok"]
    end
```

> ⚠️ **Kart ödemesi çalışmıyor** — `paymentUrl` alınıyor fakat `url_launcher` çağrısı implement edilmemiş.  
> ⚠️ **Hesabı Böl** — Yalnızca görsel hesap gösteriyor, `POST /customer/payments/split` hiç çağrılmıyor.

### 4e. Değerlendirme ve Oturum Kapatma

```mermaid
flowchart TD
    A["/review ekranı açılır"] --> B["1–5 yıldız seç"]
    B --> C["Yorum yaz (opsiyonel)"]
    C --> D["'Gönder' butonuna bas"]
    D --> E["POST /customer/reviews\n{rating, comment}"]
    E -->|"201"| F["LocalStorage.clearSessionToken()\n(oturum token temizlenir)"]
    F --> G["'Teşekkürler' ekranı"]
    G --> H["'Ana Sayfaya Dön' → /scan"]
    D2["Atla butonu"] --> H
```

---

## 5. Garson (WAITER / HEAD_WAITER) Akışı

### 5a. Genel Ekran Yapısı

```mermaid
flowchart TD
    LOGIN["/login → JWT alınır"] --> WSCR["WaiterHomeScreen\n(/waiter)\n3 Tab"]
    WSCR --> T1["Tab 1: Masalar\n(GET /waiter/tables)"]
    WSCR --> T2["Tab 2: Çağrılar 🔴\n(GET /waiter/calls)"]
    WSCR --> T3["Tab 3: Siparişler 🟢\n(GET /waiter/orders — sadece READY)"]
    
    WSCR --> REF["Manuel Yenile Butonu\n⚠️ WebSocket yok"]
```

### 5b. Masalar Sekmesi

```mermaid
flowchart TD
    T1["Masalar Grid\n(3 sütun)"] --> CARD{"Her masa kartı"}
    CARD -->|"status: AVAILABLE (Boş)"| FREE["🟢 Yeşil — tıklanamaz"]
    CARD -->|"status: OCCUPIED (Dolu)"| OCC["🟠 Turuncu — tıklanır"]
    OCC --> MODAL["BottomSheet Açılır"]
    MODAL --> OPT1["Hesap Ödenerek Kalkıldı\n→ POST /waiter/sessions/:id/close\n  {reason: PAID_BILL}"]
    MODAL --> OPT2["İşlemsiz Kalkıldı\n→ POST /waiter/sessions/:id/close\n  {reason: NO_BILL}"]
    MODAL --> OPT3["Diğer\n→ POST /waiter/sessions/:id/close\n  {reason: OTHER}"]
    OPT1 --> REFRESH["Masa listesi yenilenir"]
    OPT2 --> REFRESH
    OPT3 --> REFRESH
```

> ⚠️ **Akış Kırıklığı**: Garson masayı kapattığında ödeme kaydı **oluşturulmuyor**. `POST /waiter/payments/cash` endpoint'i var ama hiç çağrılmıyor. Nakit ödeme backend'e yazılmıyor (bkz. Bölüm 10, Sorun #6).

### 5c. Çağrılar Sekmesi

```mermaid
flowchart TD
    C2["Çağrılar Listesi\n(GET /waiter/calls)"] --> CALL{"Her çağrı"}
    CALL -->|"type: CALL_WAITER"| CW["🔔 Garson çağrısı — Masa No"]
    CALL -->|"type: REQUEST_BILL"| RB["🧾 Hesap isteniyor — Masa No"]

    CW -->|"status: PENDING"| BTN1["'Üstlen' butonu\n→ POST /waiter/calls/:id/assign"]
    CW -->|"status: IN_PROGRESS"| BTN2["'Çözüldü' butonu\n→ POST /waiter/calls/:id/resolve"]
    RB -->|"status: PENDING"| BTN3["'Üstlen' → POST /waiter/calls/:id/assign"]
    RB -->|"status: IN_PROGRESS"| BTN4["'Çözüldü' → POST /waiter/calls/:id/resolve"]

    BTN1 --> RF2["Liste yenilenir"]
    BTN2 --> RF2
    BTN3 --> RF2
    BTN4 --> RF2
```

> ⚠️ **Akış Kırıklığı**: Müşteri garson çağırdığında backend WebSocket ile bildirim gönderiyor fakat garson ekranı WebSocket dinlemiyor. Garson yeni çağrıyı ancak manuel yenileme yaparak görüyor (bkz. Bölüm 10, Sorun #3).

### 5d. Siparişler Sekmesi (Teslim Edilecekler)

```mermaid
flowchart TD
    O3["READY Siparişler\n(GET /waiter/orders)"] --> OCARD{"Her sipariş kartı"}
    OCARD --> INFO["Sipariş #ID — Masa No\nÜrün sayısı"]
    INFO --> DELBTN["'Teslim Et' butonu"]
    DELBTN --> DELAPI["POST /waiter/orders/:id/deliver\n→ status: DELIVERED"]
    DELAPI --> RF3["Liste yenilenir"]
```

---

## 6. Mutfak (CHEF) Akışı

```mermaid
flowchart TD
    LOGIN["/login → JWT alınır"] --> KSCR["KitchenScreen\n(/kitchen)"]
    KSCR --> LOAD["GET /kitchen/orders\n(PENDING + PREPARING)"]
    LOAD --> COLS["2 Sütunlu Kanban"]
    
    COLS --> COL1["Sol: Bekliyor (PENDING)\n🔴 arka plan"]
    COLS --> COL2["Sağ: Hazırlanıyor (PREPARING)\n🟠 arka plan"]

    COL1 --> CARD1{"Sipariş Kartı\nMasa No + #ID\nÜrün listesi (miktar + ad)"}
    CARD1 --> BTN_START["'Hazırlamaya Başla' butonu"]
    BTN_START --> API_START["POST /kitchen/orders/:id/start\n→ status: PREPARING"]
    API_START --> RELOAD["Ekran yenilenir"]
    RELOAD --> COL2

    COL2 --> CARD2{"Sipariş Kartı"}
    CARD2 --> BTN_READY["'Hazır' butonu"]
    BTN_READY --> API_READY["POST /kitchen/orders/:id/ready\n→ status: READY"]
    API_READY --> RELOAD2["Ekran yenilenir\nSipariş listeden çıkar"]
    API_READY --> NOTIF["⚡ WebSocket bildirimi\n→ Garson ekranına 'READY' düşer\n(Backend gönderir)"]

    KSCR --> REFBTN["Manuel Yenile Butonu\n⚠️ WebSocket yok"]
```

> ⚠️ **Akış Kırıklığı**: Yeni sipariş geldiğinde mutfak ekranı anlık güncellenmez — manuel yenile gerekiyor (bkz. Bölüm 10, Sorun #3).  
> ⚠️ **Implement Edilmemiş**: Mutfak üzerinden ürün müsaitlik yönetimi (stok durumu) için backend endpoint'ler var ama UI yok (bkz. Bölüm 10, Sorun #7).

---

## 7. Restoran Admin Akışı

### 7a. Dashboard Yapısı

```mermaid
flowchart TD
    LOGIN["/login → JWT (RESTAURANT_ADMIN)"] --> ADM["AdminDashboardScreen\n(/admin)\n4 Tab — default: Personel"]
    ADM --> TAB0["Tab 0: Masalar"]
    ADM --> TAB1["Tab 1: Menü"]
    ADM --> TAB2["Tab 2: Personel ⭐ (varsayılan)"]
    ADM --> TAB3["Tab 3: Değerlendirmeler"]
```

### 7b. Masalar Sekmesi

```mermaid
flowchart TD
    T["Masalar\n(GET /admin/tables)"] --> LIST["Masa listesi + QR görseli"]
    LIST --> ADD["+ Masa Ekle (FAB)\n→ POST /admin/tables\n{tableNumber, capacity}"]
    LIST --> EDIT["Masa Düzenle\n→ PUT /admin/tables/:id"]
    LIST --> REGEN["QR Yenile\n→ POST /admin/tables/:tableId/regenerate-qr"]
    LIST --> QRVIEW["QR Görüntüle\n→ GET /admin/tables/:tableId/qr\n(PNG byte[] döner)"]
    LIST --> DEL["Masa Sil\n→ DELETE /admin/tables/:id"]
    
    NOTE["⚠️ PUT /admin/tables/layout (drag & drop yerleşim)\nBackend'de var, UI'da yok"]
```

### 7c. Menü Sekmesi

```mermaid
flowchart TD
    M["Menü\n(GET /admin/menu/categories\nGET /admin/menu/items)"] --> CATS["Kategori Listesi"]
    CATS --> ADDCAT["Kategori Ekle\n→ POST /admin/menu/categories\n{name, nameEn, sortOrder}"]
    CATS --> EDITCAT["Kategori Düzenle\n→ PUT /admin/menu/categories/:id"]
    CATS --> DELCAT["Kategori Sil\n→ DELETE /admin/menu/categories/:id"]
    CATS --> REORDCAT["Kategori Sırala\n→ PUT /admin/menu/categories/reorder"]
    
    CATS --> ITEMS["Kategori altındaki ürünler"]
    ITEMS --> ADDITEM["Ürün Ekle\n→ POST /admin/menu/items\n{name, price, category, imageUrl...}"]
    ITEMS --> EDITITEM["Ürün Düzenle\n→ PUT /admin/menu/items/:id"]
    ITEMS --> DELITEM["Ürün Sil\n→ DELETE /admin/menu/items/:id"]
    ITEMS --> TOGGLEAVAIL["Müsaitlik Toggle\n(isAvailable: true/false)"]
    ITEMS --> REORDITEM["Ürün Sırala\n→ PUT /admin/menu/items/reorder"]
```

### 7d. Personel Sekmesi

```mermaid
flowchart TD
    S["Personel\n(GET /admin/staff)"] --> LIST2["Personel Listesi\n(Rol renkli badge — sıralı)"]
    LIST2 --> ADDSTAFF["+ Personel Ekle (FAB)\n→ POST /admin/staff"]
    LIST2 --> MOREVERT["⋮ Butonu (kendisi için gizli)"]
    MOREVERT --> EDITSTAFF["Düzenle → PUT /admin/staff/:id"]
    MOREVERT --> ACTSTAFF["Aktif/Pasif → PUT /admin/staff/:id {isActive}"]
    MOREVERT --> DELSTAFF["Sil → DELETE /admin/staff/:id"]

    ADDSTAFF --> ROLCHK{Ekleyen kim?}
    ROLCHK -->|SUPERADMIN| ALROLES["Tüm roller gösterilir\n(RESTAURANT_ADMIN dahil)"]
    ROLCHK -->|RESTAURANT_ADMIN| NOROLES["RESTAURANT_ADMIN hariç\ndiğer roller"]

    subgraph Öz_Koruma["Öz-Koruma Kuralları"]
        SC1["Kendini silemez"]
        SC2["Kendini pasif yapamaz"]
        SC3["Kendi rolünü değiştiremez"]
        SC4["UI'da ⋮ menüsü gizlenir\nBackend'de BusinessException"]
    end
```

### 7e. Değerlendirmeler Sekmesi

```mermaid
flowchart TD
    R["Değerlendirmeler\n(GET /admin/reviews)"] --> RLIST["Değerlendirme listesi\n(yıldız + yorum + tarih)"]
    RLIST --> FILTER["Filtre / sıralama\n(varsa)"]
```

---

## 8. Superadmin Akışı

```mermaid
flowchart TD
    LOGIN["/login → JWT (SUPERADMIN)"] --> SASC["SuperadminScreen\n(/superadmin)"]
    SASC --> STATS["İstatistikler:\nToplam / Aktif / Demo restoran sayısı"]
    SASC --> RLIST["Restoran Listesi\n(GET /superadmin/restaurants)"]
    RLIST --> RFAB["+ Restoran Ekle (FAB)\n→ POST /superadmin/restaurants"]
    
    RLIST --> RCARD{"Her restoran kartı"}
    RCARD --> EDIT2["Düzenle\n→ PUT /superadmin/restaurants/:id\n{name, phone, email, address}"]
    RCARD --> STAFF2["Personel Yönet\n→ _StaffScreen (modal)\n/admin/staff endpoint'leri"]
    RCARD --> SMS["SMS Gönder\n→ POST /superadmin/restaurants/:id/sms"]
    RCARD --> TOGGLE["Aktif/Pasif Toggle\n→ POST /superadmin/restaurants/:id/active"]
    RCARD --> SUB["Abonelik Yönet\n→ PUT /superadmin/restaurants/:id/subscription"]
    RCARD --> DEL2["Restoran Sil\n→ DELETE /superadmin/restaurants/:id"]
    RCARD --> IMP["Restoran Adına Giriş (Impersonate)\n→ POST /superadmin/restaurants/:id/impersonate"]
```

---

## 9. Bildirim ve WebSocket Mimarisi

### 9a. Backend Gönderim Noktaları

```mermaid
flowchart TD
    subgraph Backend_Events["Backend — WebSocket Publish"]
        E1["Yeni sipariş verildi\n→ /topic/restaurant/{id}/orders"]
        E2["Sipariş durumu değişti\n→ /topic/restaurant/{id}/orders\n→ /topic/session/{token}/status"]
        E3["⚠️ Garson çağrısı (WaiterCall)\n→ Bildirim kanalı implement edilmemiş"]
    end

    subgraph Frontend_Listeners["Frontend — WebSocket Dinleyiciler"]
        L1["WebSocketService.subscribeRestaurant()\n⚠️ HİÇBİR EKRANDA ÇAĞRILMIYOR"]
        L2["WebSocketService.subscribeSession()\n⚠️ HİÇBİR EKRANDA ÇAĞRILMIYOR"]
        L3["WebSocketService.connect()\n⚠️ HİÇBİR EKRANDA ÇAĞRILMIYOR"]
    end

    E1 -.->|"Bağlantı yok"| L1
    E2 -.->|"Bağlantı yok"| L2
```

### 9b. Mevcut (Çalışan) Güncelleme Mekanizmaları

| Ekran | Güncelleme Yöntemi | Sıklık |
|-------|--------------------|--------|
| Mutfak | Manuel yenile butonu | Elle |
| Garson | Manuel yenile butonu | Elle |
| Müşteri (Sipariş durumu) | `Timer.periodic` polling | 15 saniye |
| Admin | Manuel yenile butonu | Elle |

---

## 10. Eksiklik ve Akış Kırıklıkları Raporu

### Kritik — Akışı Tamamen Kıran Sorunlar

---

#### Sorun #1: Kart Ödemesi Çalışmıyor

**Nerede:** `payment_screen.dart` → `_pay()` metodu  
**Ne oluyor:** `POST /customer/payments/iyzico/init` çağrısı yapılıyor ve backend `paymentUrl` döndürüyor. Fakat URL, `url_launcher` ile açılmıyor — yorum satırına alınmış.

```dart
// TODO: res.data['paymentUrl'] → url_launcher ile aç
```

**Etki:** Kredi/banka kartı seçen müşteri ödeme yapamaz; herhangi bir geri bildirim almadan işlem sessizce biter.

**Çözüm:**
1. `pubspec.yaml`'a `url_launcher` ekle
2. `_pay()` içinde `launchUrl(Uri.parse(res.data['paymentUrl']))` çağır
3. Callback URL'ini backend'de ayarla

---

#### Sorun #2: Hesabı Böl — API Hiç Çağrılmıyor

**Nerede:** `payment_screen.dart` → `_showSplitDialog()`  
**Ne oluyor:** Dialog açılıyor, kişi başı tutar hesaplanıyor, fakat seçim yapınca yalnızca `Navigator.pop(ctx)` çalışıyor. `POST /customer/payments/split` hiç çağrılmıyor.

**Etki:** Müşteri "hesabı böl" yaptığını sanıyor; aslında hiçbir şey olmuyor.

**Çözüm:** Seçim butonunun `onPressed`'ine `ApiClient.instance.post(ApiConstants.customerPaymentsSplit, data: {...})` ekle.

---

#### Sorun #3: WebSocket Bağlantısı Hiç Kurulmuyor

**Nerede:** `websocket_service.dart` yazılmış; `kitchen_screen.dart`'ta `// TODO(WEBSOCKET)` yorumu var.  
**Ne oluyor:** `WebSocketService.connect()` hiçbir ekranda çağrılmıyor. Mutfak, garson ve müşteri ekranları anlık bildirim almıyor.

**Etki Zinciri:**
- Yeni sipariş geldiğinde mutfak ekranı güncellenmiyor → garson manuel yenileme yapmak zorunda
- Sipariş "READY" olduğunda garson ekranı güncellenmiyor → garson manuel yenileme yapmak zorunda  
- Müşteri sipariş çağırıca garson ekranına anlık düşmüyor → garson çağrıyı kaçırabilir
- Sipariş durumu değiştiğinde müşteri 15 saniye gecikmeyle öğreniyor

**Çözüm:**
- `kitchen_screen.dart`'ta `initState`'de `WebSocketService.instance.connect(jwtToken: ..., baseUrl: ...)` çağır
- `subscribeRestaurant(restaurantId, 'orders', ...)` ile PENDING/PREPARING siparişleri dinle
- `waiter_home_screen.dart`'ta aynısını yap ve çağrı + hazır sipariş kanallarını dinle
- `menu_screen.dart`'ta `subscribeSession(sessionToken, 'status', ...)` ile sipariş durumu dinle → `Timer.periodic` polling kaldırılabilir

---

#### Sorun #4: Nakit Ödeme Kaydı Oluşturulmuyor

**Nerede:** `waiter_home_screen.dart` → `_closeSession()` / `_TablesTab`  
**Ne oluyor:** Garson masayı "Hesap Ödenerek Kalkıldı" seçeneğiyle kapatıyor; `POST /waiter/sessions/:id/close` çağrılıyor fakat `POST /waiter/payments/cash` hiç çağrılmıyor.

**Etki:** Nakit ödeme veritabanına kayıt edilmiyor. Ödeme geçmişi, raporlama ve muhasebe çalışmıyor.

**Çözüm:** `PAID_BILL` durumunda `_closeSession()` öncesinde `POST /waiter/payments/cash` çağır.

---

### Önemli — Eksik Özellikler

---

#### Sorun #5: Sepet Ekranı (/cart) Artık Kullanılmıyor

**Nerede:** `cart_screen.dart`, rota tanımında `/cart`  
**Ne oluyor:** Eski `CartScreen` hâlâ bir rota olarak var. Yeni `menu_screen.dart` kendi `_CartSheet`'ini kullanıyor. `/cart`'a hiçbir yerden gidilmiyor fakat dosya yerinde duruyor.

**Etki:** Ölü kod. Karışıklığa yol açar.

**Çözüm:** `cart_screen.dart` dosyasını ve `/cart` rota tanımını sil; `routes.dart`'tan çıkar.

---

#### Sorun #6: VALET Rolü Ekranı Yok

**Nerede:** `routes.dart`  
**Ne oluyor:**
```dart
case 'VALET':
  return '/waiter'; // TODO: Create valet screen
```
**Etki:** Vale, garson ekranına düşüyor; ilgisi olmayan çağrı ve sipariş bilgilerini görüyor.

---

#### Sorun #7: Mutfak — Ürün Müsaitlik Yönetimi Ekranı Yok

**Nerede:** `kitchen_screen.dart`  
**Backend'de olan endpoint'ler (UI YOK):**
- `POST /kitchen/menu/{restaurantId}/items/{itemId}/availability` — ürünü stokta yok işaretle
- `POST /kitchen/menu/{restaurantId}/items/{itemId}/restore` — ürünü tekrar müsait yap
- `POST /kitchen/orders/{orderId}/priority` — sipariş içi ürün öncelik sırasını güncelle

**Etki:** Mutfak "ürün bitti" durumunu sisteme giremez; menü manuel olarak admin tarafından güncellenebiliyor.

---

#### Sorun #8: Masa Yerleşim Editörü (Layout) Yok

**Nerede:** Admin dashboard → Masalar sekmesi  
**Backend'de olan endpoint:** `PUT /admin/tables/layout`  
**Etki:** Masaların fiziksel yerleşimi sistemde güncellenemiyor.

---

#### Sorun #9: HEAD_WAITER Rolü UI'da WAITER'dan Farksız

**Nerede:** `routes.dart`, `waiter_home_screen.dart`  
**Ne oluyor:** Her ikisi de `/waiter`'a yönlendiriliyor. Baş garsonun ekstra yetkileri (örn. masa kapatma yetkisi sadece HEAD_WAITER'da olabilir) uygulanmıyor.

---

#### Sorun #10: Müşteri Oturumunun Kapanmasından Haberdar Edilmiyor

**Senaryo:** Garson masayı kapatıyor → `POST /waiter/sessions/:id/close` → müşterinin session token'ı geçersiz oluyor.  
**Ne oluyor:** Müşteri hâlâ menü ekranında duruyor, sipariş vermeye çalışıyor; backend 401/404 dönüyor.  
**Etki:** Kötü müşteri deneyimi — anlaşılmaz hata mesajları alıyor.

**Çözüm:** Backend, oturum kapandığında WebSocket ile `/topic/session/{token}/status` kanalına `SESSION_CLOSED` eventi göndersin; müşteri menü ekranı bunu dinleyerek `/review`'a yönlendirsin.

---

### Düşük Öncelik / Bilgi Notu

---

#### Sorun #11: `GET /customer/payments` Endpoint'i Kullanılmıyor

Backend `GET /customer/payments` endpoint'i mevcut fakat frontend hiçbir yerde çağırmıyor. Ödeme geçmişi müşteriye gösterilmiyor.

---

#### Sorun #12: RadioListTile Deprecation Uyarıları

**Nerede:** `payment_screen.dart` — ödeme yöntemi seçimi  
**Ne oluyor:** Flutter 3.32+ `RadioListTile.groupValue` ve `RadioListTile.onChanged`'i deprecate etti; `RadioGroup` ancestor kullanılmasını öneriyor.  
**Etki:** Yalnızca IDE uyarısı — çalışmayı etkilemiyor.

---

## Özet Tablo

| # | Sorun | Kritiklik | Etkilenen Rol | Durum |
|---|-------|-----------|---------------|-------|
| 1 | Kart ödemesi çalışmıyor (url_launcher eksik) | 🔴 Kritik | Müşteri | Açık |
| 2 | Hesabı Böl API çağrısı yok | 🔴 Kritik | Müşteri | Açık |
| 3 | WebSocket hiç bağlanmıyor | 🔴 Kritik | Müşteri / Garson / Mutfak | Açık |
| 4 | Nakit ödeme kaydedilmiyor | 🔴 Kritik | Garson | Açık |
| 5 | /cart ekranı ölü kod | 🟡 Önemli | — | Açık |
| 6 | VALET ekranı yok | 🟡 Önemli | Vale | Açık |
| 7 | Mutfak ürün müsaitlik UI yok | 🟡 Önemli | Mutfak | Açık |
| 8 | Admin masa layout editörü yok | 🟡 Önemli | Admin | Açık |
| 9 | HEAD_WAITER = WAITER (fark yok) | 🟡 Önemli | Baş Garson | Açık |
| 10 | Oturum kapanma bildirimi yok | 🟡 Önemli | Müşteri | Açık |
| 11 | GET /customer/payments kullanılmıyor | 🔵 Düşük | Müşteri | Açık |
| 12 | RadioListTile deprecation uyarısı | 🔵 Düşük | — | Açık |
