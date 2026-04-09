# Quick Serve - Restoran Yönetim Sistemi

## Proje Açıklaması
Quick Serve, bir restoran yönetim sistemidir. Müşteri ve garson işlemlerini, masa yönetimini, siparişleri, ödemeleri ve mutfak operasyonlarını yönetmek için tasarlanmıştır.

## Sistem Mimarisi

### Kullanıcı Rolleri
- **Müşteri (Customer)**: Masa QR kodunu tarayarak sipariş verebilen kullanıcılar
- **Garson (Waiter)**: Siparişleri alıp servise verebilen personel
- **Patron (Manager)**: Sistem yöneticisi, istatistikler ve raporlar görebilen kişi
- **Aşçı (Chef)**: Mutfakta siparişleri hazırlayana personel
- **Kalfa (Assistant Chef)**: Aşçıya yardımcı olan personel

### Veritabanı Tabloları

#### 1. **users**
- Tüm kullanıcı bilgilerini saklar (müşteri, garson, patron, aşçı, kalfa)
- Kimlik doğrulama için kullanılır

#### 2. **tables**
- Restoran masaları
- Durum: Boş, Dolu, Rezerve
- Her masanın QR kodu vardır

#### 3. **menu_items**
- Restoran menüsü
- Ürün adı, açıklaması, fiyatı, uygunluk durumu

#### 4. **orders**
- Siparişler
- Masa, müşteri, garson bilgisi
- Durum: Beklemede, Onaylandı, Hazırlanıyor, Hazır, Servis Edildi, Tamamlandı, İptal Edildi

#### 5. **order_items**
- Sipariş detayları (her siparişteki ürünler)
- Menü öğesi, miktar, fiyat, özel talimatlar

#### 6. **payments**
- Ödeme operasyonları
- Ödeme yöntemi: Kredi Kartı, Banka Kartı, Nakit, Mobil Ödeme
- Durum: Beklemede, Tamamlandı, Başarısız, İade Edildi

## API Endpoints

### Masalar
- `GET /api/tables` - Tüm masaları listele
- `GET /api/tables/{id}` - Masa detayları
- `POST /api/tables` - Masa oluştur
- `PUT /api/tables/{id}` - Masa güncelle
- `DELETE /api/tables/{id}` - Masa sil
- `GET /api/tables/empty` - Boş masaları listele
- `GET /api/tables/occupied` - Dolu masaları listele
- `GET /api/tables/qr/{qrCode}` - QR kodla masa bul
- `POST /api/tables/{id}/occupy` - Masayı dolu işaretle
- `POST /api/tables/{id}/empty` - Masayı boş işaretle

### Menü Öğeleri
- `GET /api/menu-items` - Tüm menü öğeleri
- `GET /api/menu-items/available` - Mevcut öğeler
- `GET /api/menu-items/{id}` - Menü öğesi detayları
- `POST /api/menu-items` - Menü öğesi oluştur
- `PUT /api/menu-items/{id}` - Menü öğesi güncelle
- `DELETE /api/menu-items/{id}` - Menü öğesi sil
- `GET /api/menu-items/search?name={name}` - Menüde ara

### Siparişler
- `GET /api/orders` - Tüm siparişler
- `GET /api/orders/{id}` - Sipariş detayları
- `POST /api/orders` - Sipariş oluştur
- `PUT /api/orders/{id}` - Sipariş güncelle
- `DELETE /api/orders/{id}` - Sipariş sil
- `GET /api/orders/pending` - Beklemede olan siparişler
- `GET /api/orders/preparing` - Hazırlanma aşamasındaki siparişler
- `GET /api/orders/ready` - Hazır siparişler
- `POST /api/orders/{id}/status/{status}` - Sipariş durumunu güncelle

### Ödemeler
- `GET /api/payments` - Tüm ödemeler
- `GET /api/payments/{id}` - Ödeme detayları
- `POST /api/payments` - Ödeme oluştur
- `PUT /api/payments/{id}` - Ödeme güncelle
- `DELETE /api/payments/{id}` - Ödeme sil
- `GET /api/payments/pending` - Beklemede olan ödemeler
- `GET /api/payments/completed` - Tamamlanan ödemeler
- `POST /api/payments/{id}/complete` - Ödemeyi tamamla
- `POST /api/payments/{id}/refund` - Ödemeyi iade et

### Kullanıcılar
- `GET /api/users` - Tüm kullanıcılar
- `GET /api/users/{id}` - Kullanıcı detayları
- `POST /api/users` - Kullanıcı oluştur
- `PUT /api/users/{id}` - Kullanıcı güncelle
- `DELETE /api/users/{id}` - Kullanıcı sil
- `GET /api/users/waiter/all` - Tüm garsonları listele
- `GET /api/users/customer/all` - Tüm müşterileri listele
- `GET /api/users/username/{username}` - Kullanıcı adıyla bul
- `POST /api/users/validate` - Kullanıcı doğrula

## Proje Yapısı

```
backend/
├── src/main/java/com/quickserve/backend/
│   ├── BackendApplication.java          # Ana uygulama sınıfı
│   ├── model/                           # Entity classes
│   │   ├── User.java
│   │   ├── UserRole.java
│   │   ├── Table.java
│   │   ├── TableStatus.java
│   │   ├── MenuItem.java
│   │   ├── Order.java
│   │   ├── OrderStatus.java
│   │   ├── OrderItem.java
│   │   ├── Payment.java
│   │   ├── PaymentMethod.java
│   │   └── PaymentStatus.java
│   ├── repository/                      # Repository (Data Access) Layer
│   │   ├── UserRepository.java
│   │   ├── TableRepository.java
│   │   ├── MenuItemRepository.java
│   │   ├── OrderRepository.java
│   │   ├── OrderItemRepository.java
│   │   └── PaymentRepository.java
│   ├── service/                         # Business Logic Layer
│   │   ├── UserService.java
│   │   ├── TableService.java
│   │   ├── MenuItemService.java
│   │   ├── OrderService.java
│   │   └── PaymentService.java
│   ├── controller/                      # REST API Layer
│   │   ├── UserController.java
│   │   ├── TableController.java
│   │   ├── MenuItemController.java
│   │   ├── OrderController.java
│   │   └── PaymentController.java
│   └── dto/                             # Data Transfer Objects
│       ├── OrderDTO.java
│       └── OrderItemDTO.java
├── src/main/resources/
│   └── application.properties           # Uygulama yapılandırması
└── pom.xml                              # Maven bağımlılıkları
```

## Gerekli Teknolojiler

- **Java 21**
- **Spring Boot 3.5.13**
- **Spring Data JPA**
- **H2 Database** (prototip için)
- **Maven**

## Konfigürasyon

### R

un Configuration
- Server Port: 8080
- Context Path: /api
- Database: H2 (In-Memory)
- H2 Console: http://localhost:8080/h2-console

## Kullanılan Teknolojiler

- **Spring Boot Starter Web**: REST API geliştirmesi için
- **Spring Boot Starter Data JPA**: Veritabanı işlemleri için
- **H2 Database**: Hafif, hızlı geliştirim veritabanı

## Başlangıç

### 1. Projeyi Klonlayın
```bash
cd /Users/hasandemir/Desktop/quick_serve/backend
```

### 2. Maven ile Derleme
```bash
mvn clean install
```

### 3. Uygulamayı Çalıştırın
```bash
mvn spring-boot:run
```

### 4. Uygulamayı Test Edin
- API: http://localhost:8080/api
- H2 Console: http://localhost:8080/h2-console

## Sonraki Adımlar

1. **Authentication & Security**: Spring Security ekleyerek kimlik doğrulama sağlayın
2. **Frontend**: React veya Vue.js ile ön yüz geliştirin
3. **Testing**: Unit testler ve integration testleri yazın
4. **Logging**: Log4j veya SLF4J kullanarak loglama ekleyin
5. **Exception Handling**: Merkezi exception handler oluşturun
6. **Search & Filtering**: Gelişmiş arama ve filtreleme özellikleri ekleyin
7. **Real-time Updates**: WebSocket kullanarak gerçek zamanlı güncellemeler sağlayın
8. **Report Generation**: Raporlama özelliği ekleyin

## İletişim

Hasan Demir - Proje Yönetimi

---

**Proje Durumu**: Geliştirme Aşamasında ✓
