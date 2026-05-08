# Git remote’lar — yeni repo (`quick_serve_repo`)

Bu depoda **iki** uzak tanımlıdır:

| Remote | URL | Amaç |
|--------|-----|------|
| `origin` | `git@github.com:hasandemircse-hub/quick_serve_repo.git` | Güncel çalışma; push/pull buraya |
| `legacy` | `git@github.com:hasandemircse-hub/quick_serve.git` | Eski repo (salt okuma / karşılaştırma); **oraya push etmeyin** |

## İlk push (henüz yapılmadıysa)

Kendi makinenizde SSH anahtarınız GitHub’a ekliyse:

```bash
cd /path/to/quick_serve
git push -u origin main
```

SSH yoksa HTTPS (Personal Access Token veya `gh auth login`):

```bash
git remote set-url origin https://github.com/hasandemircse-hub/quick_serve_repo.git
git push -u origin main
```

GitHub’da repo **boş** olmalı veya `main` çakışmasız olmalı.

## Eski repoyla fark

```bash
git fetch legacy
git log legacy/main..main --oneline
```

## Güvenlik

Eski `origin` URL’sinde PAT kullanıldıysa GitHub’da o token’ı **iptal edin**; bundan sonra yalnızca SSH veya credential helper kullanın.
