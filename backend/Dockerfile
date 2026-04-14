FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Uygulama jar'ı
COPY target/backend-0.0.1-SNAPSHOT.jar app.jar

# Log dizini
RUN mkdir -p /app/logs

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=docker

ENTRYPOINT ["java", \
  "-Xms256m", "-Xmx512m", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
