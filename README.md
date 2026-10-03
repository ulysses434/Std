# Sausage Store

Учебное приложение «магазин сосисок»: SPA-витрина, оформление заказов и сервис
отчётов. Полностью запускается локально через `docker compose`.

## Стек

| Слой             | Технологии                                        |
|------------------|---------------------------------------------------|
| Frontend         | Angular 6, TypeScript, Bootstrap, Nginx           |
| Backend          | Java 16, Spring Boot 2.6, Spring Data JPA         |
| БД основная      | PostgreSQL 15 (Flyway-миграции, Hibernate)        |
| БД отчётов       | MongoDB 7                                         |
| Сервис отчётов   | Python 3, Flask, PyMongo, APScheduler             |
| Инфраструктура   | Docker, docker compose                            |

## Архитектура

```
Браузер (http://localhost)
        │
        ▼
┌───────────────┐   /api/*   ┌─────────────────┐
│   frontend    │ ─────────► │     backend     │──► PostgreSQL (5432)
│  (nginx :80)  │            │  (Spring :8080) │──► MongoDB (27017)
└───────────────┘            └─────────────────┘
                                    ▲
                                    │ (пишет отчёты)
                             ┌──────┴──────────┐
                             │  backend-report │──► MongoDB (27017)
                             │  (Flask :8080)  │
                             └─────────────────┘
```

Сервисы в [`docker-compose.yml`](docker-compose.yml):

- `postgres` — основная БД (таблицы `product`, `orders`, `order_product`
  создаются Hibernate автоматически).
- `mongo` — БД для отчётов.
- `backend` — Spring Boot API (`/api/products`, `/api/orders`,
  `/actuator/health`, `/actuator/prometheus`).
- `backend-report` — Flask-сервис, периодически тянет отчёт и складывает в Mongo.
- `frontend` — Nginx, раздаёт SPA и проксирует `/api/*` на backend.

## Предварительные требования

- Docker Engine 20.10+ и Docker Compose v2 (`docker compose`).
- Свободные порты `80`, `5432`, `27017` на хосте.

> Если порт `80` занят, поменяйте маппинг в `docker-compose.yml`:
> `"80:80"` → `"8080:80"`.

## Быстрый старт

```bash
# 1. (опционально) настройте учётные данные БД в файле .env
cp .env.example .env

# 2. Собрать и поднять все сервисы
docker compose up -d --build

# 3. Проверить статус
docker compose ps
```

После старта откройте [http://localhost](http://localhost).

## Проверка работоспособности

```bash
# Здоровье backend
curl -s http://localhost/api/../actuator/health   # через nginx
curl -s http://localhost:8080/actuator/health      # если открыт порт backend

# Список товаров (SPA дёргает этот же endpoint)
curl -s http://localhost/api/products

# Список заказов
curl -s http://localhost/api/orders

# Создать заказ
curl -s -X POST http://localhost/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"productOrders":[{"product":{"id":1},"quantity":2}]}'

# Сервис отчётов
curl -s http://localhost:8080/health   # если открыт порт backend-report
```

Ожидаемый ответ `GET /api/products` — массив из 6 товаров (Сливочная, Особая,
Молочная, Нюренбергская, Мюнхенская, Американская).

## Конфигурация

Все значения задаются переменными окружения и имеют разумные значения по
умолчанию. Переопределить их можно в файле [`.env`](.env):

| Переменная          | По умолчанию | Описание                                  |
|---------------------|--------------|-------------------------------------------|
| `POSTGRES_DB`       | `sausage`    | Имя основной БД                           |
| `POSTGRES_USER`     | `sausage`    | Пользователь PostgreSQL                   |
| `POSTGRES_PASSWORD` | `sausage`    | Пароль PostgreSQL                         |

Backend получает `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`,
`SPRING_DATASOURCE_PASSWORD` и `SPRING_DATA_MONGODB_URI` из переменных
окружения, заданных в `docker-compose.yml`.

## Остановка и очистка

```bash
docker compose down          # остановить, удалить контейнеры и сеть
docker compose down -v       # дополнительно удалить тома с данными (БД)
```

## Запуск компонентов без Docker (для разработки)

### Backend

```bash
cd backend
mvn package
java -jar target/sausage-store-0.0.1-SNAPSHOT.jar \
  -Dspring.datasource.url=jdbc:postgresql://localhost:5432/sausage \
  -Dspring.datasource.username=sausage \
  -Dspring.datasource.password=sausage
```

### Frontend

```bash
cd frontend
npm install
npm run build
npx http-server ./dist/frontend -p 8080 --proxy http://localhost:8080
```

### Backend-report

```bash
cd backend-report
pip install -r requirements.txt
PORT=8080 DB=mongodb://localhost:27017/reports python app.py
```
