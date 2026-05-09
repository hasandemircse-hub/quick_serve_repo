# edge-frontend

Restoran içi operasyon uygulaması (garson/mutfak/kasa).

Bu klasör hedefte:
- edge API'ye bağlanan staff ekranları
- offline/LAN öncelikli çalışma
- cloud bağımlılığının minimize edilmesi

Bu klasör artık bağımsız Flutter app entrypoint'i içerir.

## Edge sunucuda: sadece git + compose (önerilen)

`.env.edge` içine **personel cihazının tarayıcısından** erişilecek adresleri yaz:

```env
EDGE_API_URL=http://192.168.1.50:8081/api
CLOUD_API_URL=http://192.168.1.50:8080/api
```

Sonra repo kökünde:

```bash
git pull
docker compose --env-file .env.edge -f docker-compose.edge.yml up -d --build
```

Arayüz: `http://<SUNUCU_IP>:8082` (veya `EDGE_FRONTEND_PORT`). İlk build Flutter indirdiği için uzun sürebilir.

`EDGE_API_URL` / `CLOUD_API_URL` değişince frontend’i yeniden derlemek için: `docker compose ... build --no-cache edge-frontend` veya `up -d --build`.

## Yerelde artifact (Docker kullanmadan)

```bash
EDGE_API_URL=http://... CLOUD_API_URL=http://... ./apps/edge-frontend/build_web.sh
```

## Lokal doğrulama

```bash
cd apps/edge-frontend
flutter pub get
flutter analyze
```

Opsiyonel env:

- `EDGE_API_URL` (default: `http://localhost:8081/api`)
- `CLOUD_API_URL` (default: `http://localhost:8080/api`)
