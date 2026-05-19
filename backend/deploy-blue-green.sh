#!/bin/bash
set -e

BLUE_CONTAINER="backend-blue"
GREEN_CONTAINER="backend-green"

ACTIVE_COLOR=""
if docker ps --format '{{.Names}}' | grep -q "^${BLUE_CONTAINER}$"; then
    ACTIVE_COLOR="blue"
elif docker ps --format '{{.Names}}' | grep -q "^${GREEN_CONTAINER}$"; then
    ACTIVE_COLOR="green"
fi

if [ "$ACTIVE_COLOR" == "blue" ]; then
    NEW_COLOR="green"
    OLD_COLOR="blue"
else
    NEW_COLOR="blue"
    OLD_COLOR="green"
fi

echo "Активный цвет: $ACTIVE_COLOR, новый цвет: $NEW_COLOR"

docker stop "${NEW_COLOR}-container" 2>/dev/null || true
docker rm "${NEW_COLOR}-container" 2>/dev/null || true

docker run -d \
    --name "${NEW_COLOR}-container" \
    --network sausagestore_sausage-store \
    --restart unless-stopped \
    -e SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL}" \
    -e SPRING_DATASOURCE_USERNAME="${SPRING_DATASOURCE_USERNAME}" \
    -e SPRING_DATASOURCE_PASSWORD="${SPRING_DATASOURCE_PASSWORD}" \
    -e SPRING_DATA_MONGODB_URI="${REPORTS_MONGODB_URI}" \
    -e VIRTUAL_HOST="backend" \
    -e VIRTUAL_PORT="8080" \
    -v /opt/certs/CA.pem:/app/postgres.crt:ro \
    -v /opt/certs/CA.pem:/app/root.crt:ro \
    --add-host=host.docker.internal:host-gateway \
    --health-cmd="curl --fail -s http://localhost:8080/actuator/health" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-start-period=30s \
    --health-retries=5 \
    "${CI_REGISTRY_IMAGE}/sausage-store/backend:${VERSION}"

echo "Ожидание, пока новый контейнер станет healthy..."

for i in $(seq 1 24); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${NEW_COLOR}-container" 2>/dev/null)
    if [ "$STATUS" == "healthy" ]; then
        echo "Новый контейнер $NEW_COLOR здоров."
        break
    fi
    sleep 5
done

if [ "$STATUS" != "healthy" ]; then
    echo "ОШИБКА: новый контейнер не стал healthy. Откат."
    docker stop "${NEW_COLOR}-container" || true
    exit 1
fi

# Останавливаем старый контейнер
if [ -n "$OLD_COLOR" ]; then
    docker stop "${OLD_COLOR}-container" 2>/dev/null || true
    docker rm "${OLD_COLOR}-container" 2>/dev/null || true
    echo "Старый контейнер $OLD_COLOR остановлен."
fi

echo "Blue-green деплой завершён. Трафик переключён на $NEW_COLOR."