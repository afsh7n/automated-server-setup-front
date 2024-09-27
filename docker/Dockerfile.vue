# Dockerfile for Vue Project
FROM node:16-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

RUN npm install -g serve
EXPOSE 8080
CMD ["serve", "-s", "dist"]
