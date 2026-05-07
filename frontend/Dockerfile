FROM node:16.20.0-alpine3.18 as builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
FROM nginx:stable-alpine3.17-slim
WORKDIR /app/frontend
COPY --from=builder /app/dist/frontend/. /app/frontend/
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]