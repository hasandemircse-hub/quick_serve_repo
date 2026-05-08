# QuickServe

Restoran yönetimi: **cloud** (PostgreSQL, müşteri ve merkez iş kuralları) + **edge** (SQLite, LAN personeli, senkronizasyon, POS/yazıcı soyutlama). Flutter web: `cloud-frontend` (müşteri/superadmin ağırlıklı) ve `edge-frontend` (personel).

## Hızlı yön

| Ne arıyorsunuz | Dosya / klasör |
|----------------|----------------|
| Mimari, deploy, senaryolar, eksikler | [docs/QUICKSERVE_SYSTEM_REFERENCE.md](docs/QUICKSERVE_SYSTEM_REFERENCE.md) |
| Geliştirici komutları, katman yapısı | [CLAUDE.md](CLAUDE.md) |
| Git: `origin` vs `legacy` remote | [docs/git_remotes_and_migration.md](docs/git_remotes_and_migration.md) |
| Cloud backend | `apps/cloud-backend` |
| Edge backend | `apps/edge-backend` |
| Ortak Flutter | `packages/shared-frontend` |
| Lokal cloud+edge | `scripts/up_local_cloud_edge.sh` |

## Gereksinimler (özet)

- **Cloud:** Java 21+, PostgreSQL 16, Maven  
- **Edge:** Java 21+, Maven, SQLite (dosya yolu env ile)  
- **Frontend:** Flutter 3.11+

## Lisans

Belirtilmediyse proje içi dosyalara bakın.
