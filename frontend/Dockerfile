FROM node:16.20.0-alpine3.18 as builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM jwilder/nginx-proxy:alpine
COPY nginx.tmpl /app/nginx.tmpl
COPY --from=builder /app/dist/frontend/. /usr/share/nginx/html/
EXPOSE 80