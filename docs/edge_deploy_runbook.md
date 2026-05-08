# QuickServe Edge Deploy Runbook (Mini PC)

Bu runbook, restoran içindeki edge mini PC'ye QuickServe Edge kurulumu için hazırlanmıştır.
Amaç: hızlı kurulum + hızlı doğrulama + hızlı rollback.

---

## 1) Ön Koşullar

- OS: Ubuntu 22.04+ (önerilen) veya Docker destekli Linux
- CPU/RAM: en az 2 vCPU / 4 GB RAM
- Disk: en az 20 GB boş alan
- Ağ:
  - LAN erişimi açık
  - Cloud API erişimi açık (internet)
- Saat senkronizasyonu (NTP) açık olmalı

---

## 2) Sunucu Hazırlığı

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
```

Docker kurulumu:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Not: Grup değişikliği için oturumu kapatıp açın.

Docker Compose kontrolü:

```bash
docker compose version
```

---

## 3) Dosyaları Edge Cihaza Alma

Repo'yu edge cihaza çek:

```bash
git clone <REPO_URL> quick_serve
cd quick_serve
```

Edge env dosyasını oluştur:

```bash
cp .env.edge.example .env.edge
```

`.env.edge` içinde en az şu alanları doldur:
- `EDGE_NODE_ID`
- `EDGE_RESTAURANT_ID`
- `EDGE_CLOUD_BASE_URL`
- `EDGE_ENROLLMENT_TOKEN`
- `EDGE_SQLITE_PATH`
- `EDGE_IMAGE_TAG` (release dağıtımda)
- (opsiyonel) sync cleanup/retention ayarları (`EDGE_SYNC_MAINTENANCE_*`, `EDGE_SYNC_RETENTION_*`)
- (opsiyonel) gerçek POS provider ayarları (`EDGE_POS_HTTP_*`; `EDGE_POS_DEFAULT_PROVIDER=http-pos`)
  - provider response alan adları farklıysa `EDGE_POS_HTTP_RESPONSE_*` alanları ile mapping yapılır

---

## 4) Edge Servislerini Ayağa Kaldırma

Geliştirme/lokal mod:

```bash
docker compose --env-file .env.edge -f docker-compose.edge.yml up -d
```

Release (tag pin + pull policy) modu:

```bash
./scripts/deploy_edge_release.sh --tag <IMAGE_TAG>
```

Deploy sonrası script, varsayılan olarak edge üzerinde `GET /api/actuator/health` ile sağlık kontrolü yapar (birkaç dakikaya kadar yeniden dener). Başarısız olursa ve daha önce kayıtlı bir önceki image tag’i varsa **otomatik rollback** uygulanır.

İsteğe bağlı bayraklar:

```bash
# Health beklemeden sadece compose up (özel durumlar)
./scripts/deploy_edge_release.sh --tag <IMAGE_TAG> --skip-health-check

# Health başarısız olsa bile otomatik geri alma yapma
./scripts/deploy_edge_release.sh --tag <IMAGE_TAG> --no-auto-rollback
```

LAN üzerinden farklı host/port ile health denemek için `.env.edge` içine `EDGE_HEALTH_URL=...` ekleyin veya shell’de export edin.

Durum kontrol:

```bash
docker compose --env-file .env.edge -f docker-compose.edge.deploy.yml ps
```

Log kontrol:

```bash
docker compose --env-file .env.edge -f docker-compose.edge.deploy.yml logs -f --tail=200
```

---

## 5) Health ve Smoke Kontrol

Repo kökünde smoke script çalıştır:

```bash
EDGE_API_BASE_URL=http://localhost:8081/api ./scripts/smoke_cloud_edge.sh
```

Beklenen:
- Edge health PASS
- Cloud erişimi varsa cloud health PASS
- Manuel checklist adımları ile UI doğrulama

---

## 6) Operasyon Komutları

Yeniden başlat:

```bash
docker compose --env-file .env.edge -f docker-compose.edge.deploy.yml restart
```

Durdur:

```bash
docker compose --env-file .env.edge -f docker-compose.edge.deploy.yml down
```

Güncel image çek:

```bash
./scripts/deploy_edge_release.sh --tag <NEW_TAG>
```

---

## 7) Rollback (Hızlı Geri Dönüş)

1. Önceki sürüme otomatik dön:

```bash
./scripts/deploy_edge_release.sh --rollback
```

2. Health/smoke testi tekrar çalıştır.

---

## 8) Bilinen Geçiş Notları

- Release dağıtımı için `docker-compose.edge.deploy.yml` kullanılmalıdır.
- Release compose içinde edge backend image GHCR'dan `EDGE_IMAGE_TAG` ile pinlenir.
- `pull_policy: always` ile her deploy adımında hedef tag yeniden çekilir.
- Lokal hızlı geliştirme için `docker-compose.edge.yml` (build tabanlı) kullanılabilir.
- Edge runtime kalıcı veri katmanı SQLite dosyasıdır (`/data/edge.db`).
- Sync queue bakım işi varsayılan açık gelir; outbox/inbox için retention süresi dolan `SENT/PROCESSED/DEAD` kayıtları saatlik temizlenir (env ile ayarlanabilir).
- Gerçek POS entegrasyonu için `http-pos` adapter env ile açılabilir; timeout ve auth header/token alanları `EDGE_POS_HTTP_*` değişkenleri ile yönetilir.
- POS çift çekim koruması: `POST .../device/pos/charge` gövdesinde opsiyonel `idempotencyKey`; edge SQLite `edge_pos_charge_audit` tablosunda tutulur, periyodik temizlik `EDGE_POS_AUDIT_RETENTION_DAYS` (varsayılan 90).
- Provider cevap sözleşmesi farklı ise başarı/error/transaction alanları `EDGE_POS_HTTP_RESPONSE_*` ile uyarlanabilir (kod değişmeden vendor adaptasyonu).

---

## 9) Incident Kısa Kontrol Listesi

1. `docker compose ... ps` ile container ayakta mı?
2. `docker compose ... logs` içinde bağlantı/JWT/DB hatası var mı?
3. `EDGE_CLOUD_BASE_URL` doğru mu?
4. Edge portu (`8081`) LAN'da erişilebilir mi?
5. Gerekirse rollback adımı uygula.
