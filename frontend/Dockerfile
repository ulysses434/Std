FROM node:16.20.0-alpine3.18 as builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.25-alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist/frontend/. /usr/share/nginx/html/
EXPOSE 80
