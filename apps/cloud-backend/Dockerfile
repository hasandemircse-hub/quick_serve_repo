FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

COPY target/cloud-backend-0.0.1-SNAPSHOT.jar app.jar

RUN mkdir -p /app/logs

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=docker

ENTRYPOINT ["java", \
  "-Xms256m", "-Xmx512m", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
