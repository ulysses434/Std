FROM maven:3.9.3-eclipse-temurin-20-alpine AS builder
WORKDIR /usr/src/app
COPY ./src ./src
COPY pom.xml ./
RUN mvn package -Dmaven.test.skip=true \
    && mv target/*.jar target/app.jar

FROM eclipse-temurin:17-jre-alpine
RUN apk add --no-cache curl \
    && addgroup --system jaruser \
    && adduser -S -s /bin/false -G jaruser jaruser -D -H
WORKDIR /app
COPY --chown=jaruser:jaruser \
     --from=builder /usr/src/app/target/app.jar ./sausage-store.jar
EXPOSE 8080
USER jaruser
ENTRYPOINT ["java", "-jar", "-Dmyserver.bindPort=8080", "/app/sausage-store.jar"]
