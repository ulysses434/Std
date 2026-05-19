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

if [ -n "$OLD_COLOR" ]; then
    echo "Останавливаю старый контейнер $OLD_COLOR, чтобы освободить соединения с БД"
    docker stop "${OLD_COLOR}" 2>/dev/null || true
fi

docker stop "${NEW_COLOR}" 2>/dev/null || true
docker rm "${NEW_COLOR}" 2>/dev/null || true

docker run -d \
    --name "${NEW_COLOR}" \
    --network sausagestore_sausage-store \
    --restart unless-stopped \
    -e SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL}" \
    -e SPRING_DATASOURCE_USERNAME="${SPRING_DATASOURCE_USERNAME}" \
    -e SPRING_DATASOURCE_PASSWORD="${SPRING_DATASOURCE_PASSWORD}" \
    -e SPRING_DATA_MONGODB_URI="${REPORTS_MONGODB_URI}" \
    -e SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=5 \
    -e VIRTUAL_HOST=backend \
    -e VIRTUAL_PORT=8080 \
    -v /opt/certs/CA.pem:/app/postgres.crt:ro \
    -v /opt/certs/CA.pem:/app/root.crt:ro \
    --add-host=host.docker.internal:host-gateway \
    --health-cmd="curl --fail -s http://localhost:8080/actuator/health" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-start-period=90s \
    --health-retries=5 \
    "${CI_REGISTRY_IMAGE}/sausage-store/backend:${VERSION}"

echo "Ожидание, пока новый контейнер станет healthy (до 180 секунд)..."
HEALTHY=0
for i in $(seq 1 36); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${NEW_COLOR}" 2>/dev/null)
    if [ "$STATUS" == "healthy" ]; then
        echo "Новый контейнер $NEW_COLOR здоров."
        HEALTHY=1
        break
    fi
    sleep 5
done

if [ $HEALTHY -eq 0 ]; then
    echo "ОШИБКА: новый контейнер не стал healthy за 180 секунд."
    echo "Логи нового контейнера:"
    docker logs "${NEW_COLOR}"
    docker stop "${NEW_COLOR}" 2>/dev/null || true
    docker rm "${NEW_COLOR}" 2>/dev/null || true

    if [ -n "$OLD_COLOR" ]; then
        echo "Возвращаю старый контейнер $OLD_COLOR"
        docker start "${OLD_COLOR}"
    fi
    exit 1
fi

if [ -n "$OLD_COLOR" ]; then
    docker rm "${OLD_COLOR}" 2>/dev/null || true
    echo "Старый контейнер $OLD_COLOR удалён."
fi

echo "Blue-green деплой завершён. Трафик переключён на $NEW_COLOR."