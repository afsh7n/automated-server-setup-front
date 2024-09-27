# Dockerfile for Vue Project
FROM node:16-alpine AS builder

WORKDIR /usr/src/app

# Install dependencies and build the project
COPY ./../src/onomis-vue/package*.json ./
RUN npm install
COPY ./../src/onomis-vue ./
RUN npm run build

# Final stage: Copy build files to a dedicated directory in Nginx
FROM nginx:alpine
COPY --from=builder /usr/src/app/dist /usr/share/nginx/html/onomis-vue
