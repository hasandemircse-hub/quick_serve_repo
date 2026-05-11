# edge-frontend

Restoran içi operasyon uygulaması (garson/mutfak/kasa).

Bu klasör hedefte:
- edge API'ye bağlanan staff ekranları
- offline/LAN öncelikli çalışma
- cloud bağımlılığının minimize edilmesi

Bu klasör artık bağımsız Flutter app entrypoint'i içerir.

### API adresleri (`assets/edge_frontend.env`)

Chrome / web için **cloud IP ve edge port** değerlerini `apps/edge-frontend/assets/edge_frontend.env` dosyasına yazın; uygulama açılışta `flutter_dotenv` ile okur (Spring `application.properties` veya `.env.edge` ile aynı değil — Flutter tarayıcıda çalıştığı için asset dosyası gerekir). İsteğe bağlı `--dart-define` hâlâ çalışır; dosyada dolu olan anahtarlar onların üzerine yazar.

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

Önce `assets/edge_frontend.env` içindeki `CLOUD_API_URL` / `EDGE_API_URL` değerlerini düzenleyin. Sonra:

```bash
cd apps/edge-frontend
flutter pub get
flutter run -d chrome
```

### Sabit port (ör. 8088) — neden bazen 65xxx olur?

`--web-port=8088` verilmiş olsa bile **8088 başka bir süreçte kullanılıyorsa** Flutter bağlanamaz ve **rastgele boş bir port** seçer (ör. 65210). Kontrol: `lsof -iTCP:8088 -sTCP:LISTEN` (macOS). Boş bir port seçin veya çakışan uygulamayı kapatın.

VS Code: **Run and Debug** açılırken üstte **doğru launch profilini** seçtiğinizden emin olun (`.vscode/launch.json`). **web-server** profili: sunucu her zaman `http://localhost:8088`; Chrome’u elle bu adrese açın.

İsteğe bağlı: `run_dev_chrome.sh` (port için `FLUTTER_WEB_PORT`) veya `--dart-define` ile geçici override.
