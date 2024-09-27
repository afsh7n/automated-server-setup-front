# Dockerfile for Vue Project
FROM node:16-alpine

WORKDIR /usr/src/app

COPY ./../src/onomis-vue/package*.json ./

RUN npm install

COPY ./../src/onomis-vue/. ./

RUN npm run build

RUN npm install -g serve

EXPOSE 8080

CMD ["serve", "-s", "dist"]
