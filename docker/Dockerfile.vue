FROM node:16-alpine AS builder
WORKDIR /usr/src/app
COPY ./../src/onomis-vue/package*.json ./
RUN npm install
COPY ./../src/onomis-vue/. .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /usr/src/app/dist /usr/share/nginx/html/onomis-vue
EXPOSE 80
