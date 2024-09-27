# Dockerfile for Vue Project
FROM node:16-alpine

WORKDIR /usr/src/app
COPY ./../src/onomis-vue/package*.json ./
RUN npm install
COPY ./../src/onomis-vue/. .
RUN npm run build
