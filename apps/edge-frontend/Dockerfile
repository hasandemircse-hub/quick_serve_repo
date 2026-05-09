# Build context: repo kökü (packages/shared-frontend path bağımlılığı için).
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /build
COPY packages/shared-frontend /build/packages/shared-frontend
COPY apps/edge-frontend /build/apps/edge-frontend

WORKDIR /build/apps/edge-frontend

# Tarayıcıdan erişilecek API kökleri — .env.edge içinden compose build-args ile gelir.
ARG EDGE_API_URL=http://127.0.0.1:8081/api
ARG CLOUD_API_URL=http://127.0.0.1:8080/api

RUN flutter config --enable-web \
  && flutter pub get \
  && flutter build web --release \
    --dart-define=API_URL=${EDGE_API_URL} \
    --dart-define=EDGE_API_URL=${EDGE_API_URL} \
    --dart-define=CLOUD_API_URL=${CLOUD_API_URL}

FROM nginx:alpine
COPY --from=build /build/apps/edge-frontend/build/web /usr/share/nginx/html
COPY nginx.edge-frontend.conf /etc/nginx/conf.d/default.conf
