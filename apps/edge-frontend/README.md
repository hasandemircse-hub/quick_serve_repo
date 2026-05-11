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

## Lokal doğrulama (Chrome)

**Düz `flutter run -d chrome` kullanmayın.** `shared-frontend` içinde `CLOUD_API_URL` compile-time `String.fromEnvironment` ile gelir; argüman verilmezse cloud adresi **`http://localhost:8080/api`** kalır → login `POST .../auth/login` oraya gider ve `ERR_CONNECTION_REFUSED` görürsünüz.

Repo kökündeki `.env.edge` dosyanızda `EDGE_API_URL` ve `CLOUD_API_URL` tanımlıysa:

```bash
chmod +x apps/edge-frontend/run_dev_chrome.sh
./apps/edge-frontend/run_dev_chrome.sh
```

VS Code: kök `.vscode/launch.json` içindeki **Flutter edge-frontend (Chrome → cloud VM)** profilini seçin (içinde `--dart-define=CLOUD_API_URL=...` vardır). Alternatif: **Terminal → Run Task… → edge-frontend: Chrome (run_dev_chrome.sh)**.

```bash
cd apps/edge-frontend
flutter pub get
flutter analyze
```

Dart-define özet (web build ile aynı mantık):

- `EDGE_API_URL` (edge API; default betikte: `http://127.0.0.1:8081/api`)
- `CLOUD_API_URL` (JWT login ve müşteri tarafı cloud çağrıları; betikte yoksa `http://192.168.139.157/api`)
