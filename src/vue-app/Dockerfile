# Base image
FROM node:14

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy all files to the container
COPY . .

# Expose port 8080
EXPOSE 8080

# Disable host checking for Vue CLI and set host
ENV CHOKIDAR_USEPOLLING=true
ENV VUE_CLI_SERVICE_URL=http://localhost

# Start the Vue app with host 0.0.0.0
CMD ["npm", "run", "serve", "--", "--host", "0.0.0.0", "--port", "8080"]
