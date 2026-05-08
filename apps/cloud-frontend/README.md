# cloud-frontend

Cloud tarafı yönetim uygulaması (superadmin ağırlıklı).

Bu klasör hedefte:
- superadmin paneli
- edge node/fleet görünümü
- restoran bazlı paket ve ayar yönetimi

Bu klasör artık bağımsız Flutter app entrypoint'i içerir.

## Artifact üretimi

```bash
./apps/cloud-frontend/build_web.sh
```

## Lokal doğrulama

```bash
cd apps/cloud-frontend
flutter pub get
flutter analyze
```

Opsiyonel env:

- `CLOUD_API_URL` (default: `http://localhost:8080/api`)
- `WEB_ADMIN_URL` (default: `http://localhost:8080/auth/admin`)
