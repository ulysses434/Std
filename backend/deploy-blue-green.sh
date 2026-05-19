#!/bin/bash
set -e

BLUE_SERVICE="backend-blue"
GREEN_SERVICE="backend-green"

ACTIVE_SERVICE=""
if docker compose ps --format '{{.Names}}' | grep -q "^${BLUE_SERVICE}$"; then
    ACTIVE_SERVICE="${BLUE_SERVICE}"
elif docker compose ps --format '{{.Names}}' | grep -q "^${GREEN_SERVICE}$"; then
    ACTIVE_SERVICE="${GREEN_SERVICE}"
fi

if [ "$ACTIVE_SERVICE" == "${BLUE_SERVICE}" ]; then
    NEW_SERVICE="${GREEN_SERVICE}"
    OLD_SERVICE="${BLUE_SERVICE}"
else
    NEW_SERVICE="${BLUE_SERVICE}"
    OLD_SERVICE="${GREEN_SERVICE}"
fi

echo "Активный сервис: $ACTIVE_SERVICE, новый сервис: $NEW_SERVICE"

if [ -n "$OLD_SERVICE" ] && [ "$ACTIVE_SERVICE" != "$NEW_SERVICE" ]; then
    echo "Останавливаю старый сервис $OLD_SERVICE..."
    docker compose stop "${OLD_SERVICE}" 2>/dev/null || true
    docker compose rm -f "${OLD_SERVICE}" 2>/dev/null || true
fi

echo "Запускаю новый сервис ${NEW_SERVICE}..."
docker compose up -d --no-deps --scale "${NEW_SERVICE}=1" "${NEW_SERVICE}"

echo "Ожидание, пока новый контейнер станет healthy (до 180 секунд)..."
HEALTHY=0
for i in $(seq 1 36); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${NEW_SERVICE}" 2>/dev/null)
    if [ "$STATUS" == "healthy" ]; then
        echo "Новый контейнер $NEW_SERVICE здоров."
        HEALTHY=1
        break
    fi
    sleep 5
done

if [ $HEALTHY -eq 0 ]; then
    echo "ОШИБКА: новый контейнер не стал healthy."
    echo "Логи нового контейнера:"
    docker compose logs "${NEW_SERVICE}"
    docker compose stop "${NEW_SERVICE}" 2>/dev/null || true
    docker compose rm -f "${NEW_SERVICE}" 2>/dev/null || true

    if [ -n "$OLD_SERVICE" ]; then
        echo "Возвращаю старый сервис $OLD_SERVICE"
        docker compose start "${OLD_SERVICE}"
    fi
    exit 1
fi

if [ -n "$OLD_SERVICE" ]; then
    echo "Старый сервис $OLD_SERVICE удалён."
fi

echo "Blue-green деплой завершён. Трафик переключён на $NEW_SERVICE."