# edge-frontend

Restoran içi operasyon uygulaması (garson/mutfak/kasa).

Bu klasör hedefte:
- edge API'ye bağlanan staff ekranları
- offline/LAN öncelikli çalışma
- cloud bağımlılığının minimize edilmesi

Bu klasör artık bağımsız Flutter app entrypoint'i içerir.

## Artifact üretimi

```bash
./apps/edge-frontend/build_web.sh
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
