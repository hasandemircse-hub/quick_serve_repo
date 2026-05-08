# cloud-backend

Cloud control-plane backend uygulaması.

Bu klasör cloud control-plane için tek Maven/Docker entrypoint'idir; kaynak kod `src/main/java` altındadır.

## Çalıştırma

```bash
cd apps/cloud-backend
mvn spring-boot:run
```

## Build

```bash
cd apps/cloud-backend
mvn package -DskipTests
```

## Docker

```bash
docker build -t quickserve-cloud-backend:local ./apps/cloud-backend
```
