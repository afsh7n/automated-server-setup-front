# Dockerfile for Vue Project
FROM node:16-alpine

WORKDIR /usr/src/app

# Install dependencies and serve globally
COPY ./../src/onomis-vue/package*.json ./
RUN npm install
RUN npm install -g serve

# Copy application source code
COPY ./../src/onomis-vue/. ./

# Build the Vue project
RUN npm run build

# Expose port and start the server
EXPOSE 8080
CMD ["serve", "-s", "dist"]
