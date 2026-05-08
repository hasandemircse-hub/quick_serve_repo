# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Canonical architecture & scenarios:** [docs/QUICKSERVE_SYSTEM_REFERENCE.md](docs/QUICKSERVE_SYSTEM_REFERENCE.md) (topology, deploy, gaps, flow catalog).

**Git remotes:** [docs/git_remotes_and_migration.md](docs/git_remotes_and_migration.md) — `origin` = `quick_serve_repo`, `legacy` = eski `quick_serve`; push yalnızca `origin`.

QuickServe is a restaurant management platform with:
- **Backend:** Spring Boot 3.x (Java 21, Maven), PostgreSQL 16
- **Frontend:** Flutter 3.11+ (Dart), multi-platform (web + mobile)
- **Infra:** Docker Compose + Nginx reverse proxy, deployed to a Linux VM

## Development Commands

### Backend (cloud)
```bash
cd apps/cloud-backend
mvn spring-boot:run             # Start dev server on :8080/api
mvn test                        # Run all tests
mvn clean package -DskipTests   # Build JAR
```
Swagger UI available at `http://localhost:8080/api/swagger-ui.html`

### Frontend
Shared UI/logic: `packages/shared-frontend`. Web apps: `apps/cloud-frontend` (müşteri/cloud), `apps/edge-frontend` (personel/edge).

```bash
cd apps/cloud-frontend   # veya apps/edge-frontend
flutter pub get
flutter run -d chrome
./build_web.sh           # release web (cloud-frontend; env ile API URL)
```

`packages/shared-frontend` içinde birim testleri: `cd packages/shared-frontend && flutter test`

### Full Stack (Docker)
```bash
cp .env.example .env            # Fill in secrets
docker compose up -d            # Start all services
docker compose logs -f backend  # Tail backend logs
```

## Architecture

### Backend Layer Structure
```
Controller → Service → Repository (JPA)
```
- Controllers in `apps/cloud-backend/.../controller/` — one per domain (auth, customer, waiter, kitchen, admin, superadmin)
- Services contain all business logic; repositories are plain JPA interfaces
- Schema managed by Hibernate `ddl-auto=update` (no migration files)
- Superadmin is auto-seeded on first startup via `@PostConstruct` in `AuthService`

### Frontend Feature Structure
```
packages/shared-frontend/lib/features/[role]/
  ├── screens/        # UI screens
  ├── providers/      # Riverpod state providers
  └── widgets/        # Role-specific widgets
```
Roles: `auth`, `customer`, `waiter`, `kitchen`, `admin`, `superadmin`

State management: Riverpod + Riverpod Annotations (code-gen). HTTP: Dio + Retrofit (code-gen). Navigation: GoRouter with role-based guards in `lib/routes.dart`.

### Authentication
- **Staff:** JWT Bearer token — `POST /auth/login` → `Authorization: Bearer {jwtToken}` (24h expiry)
- **Customers:** Session token — `POST /customer/scan/:qrToken` → `X-Session-Token: {sessionToken}` (anonymous, scoped to table session)

Roles (descending): `SUPERADMIN > RESTAURANT_ADMIN > HEAD_WAITER > WAITER > CHEF > VALET`

### Real-time (WebSocket)
STOMP over SockJS. Topics:
- `/topic/restaurant/{restaurantId}/orders` — new orders and status changes
- `/topic/session/{sessionToken}/status` — customer order status
- `/topic/waiter/calls` — waiter call notifications

`WebSocketService` exists in the frontend but is **not currently wired into any screen** — screens use polling instead.

### CI/CD
GitHub Actions (`.github/workflows/ci-cd.yml`):
1. **Test** — PostgreSQL service container + `mvn test` in `apps/cloud-backend`
2. **Build** — Flutter web build, Maven package, Docker image pushed to `ghcr.io`
3. **Deploy** — SCP Flutter build, pull image, `docker compose up -d` on VM, health-check `/api/actuator/health`

## Key Known Issues (see `PROJE_DOKUMANI.md` for full details)
- WebSocket never connected — all real-time relies on polling
- Credit card payment URL not launched (`url_launcher` not called)
- Cash payment flow not recorded to backend
- HEAD_WAITER role has no distinct UI from WAITER
- VALET role screen missing

## Environment Variables
Required secrets (see `.env.example`): `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, `FRONTEND_URL`, `CORS_ORIGINS`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `NETGSM_*`, `SUPERADMIN_*`

CI/CD secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`
