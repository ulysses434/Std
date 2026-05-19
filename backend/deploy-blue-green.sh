#!/bin/bash
set -e

BLUE_CONTAINER="backend-blue"
GREEN_CONTAINER="backend-green"

ACTIVE_COLOR=""
if docker compose ps --format '{{.Names}}' | grep -q "^${BLUE_CONTAINER}$"; then
    ACTIVE_COLOR="blue"
elif docker compose ps --format '{{.Names}}' | grep -q "^${GREEN_CONTAINER}$"; then
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
    echo "Останавливаю старый сервис $OLD_COLOR..."
    docker compose stop "${OLD_COLOR}" 2>/dev/null || true
    docker compose rm -f "${OLD_COLOR}" 2>/dev/null || true
fi

echo "Запускаю новый сервис ${NEW_COLOR}..."
docker compose up -d --no-deps --scale "${NEW_COLOR}=1" "${NEW_COLOR}"

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
    echo "ОШИБКА: новый контейнер не стал healthy."
    echo "Логи нового контейнера:"
    docker compose logs "${NEW_COLOR}"
    docker compose stop "${NEW_COLOR}" 2>/dev/null || true
    docker compose rm -f "${NEW_COLOR}" 2>/dev/null || true

    if [ -n "$OLD_COLOR" ]; then
        echo "Возвращаю старый сервис $OLD_COLOR"
        docker compose start "${OLD_COLOR}"
    fi
    exit 1
fi

if [ -n "$OLD_COLOR" ]; then
    echo "Старый сервис $OLD_COLOR успешно удалён."
fi

echo "Blue-green деплой завершён. Трафик переключён на $NEW_COLOR."