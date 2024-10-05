# Use a lightweight Node.js image
FROM node:20-alpine

ARG FOLDER_NAME
ARG PORT

# Set environment variable for the port
ENV PORT=${PORT}

# Set working directory
WORKDIR /usr/src/app

# Echo the folder name to check if it's passed correctly (for debugging)
RUN echo "Building folder: ${FOLDER_NAME}"


# Install Yarn globally
RUN npm install -g yarn --force

# Copy package.json and install dependencies
COPY ./../src/${FOLDER_NAME}/package*.json ./

RUN yarn install

# Copy the entire project to the container
COPY ./../src/${FOLDER_NAME}/. .

# Build the project
RUN yarn build

# Install serve to serve static files
RUN npm install -g serve

# Copy the start script to the container
COPY ./docker/start.sh /usr/src/app/start.sh

# Make the start script executable
RUN chmod +x /usr/src/app/start.sh

# Expose the port serve will run on
EXPOSE ${PORT}

# Use the start script to serve the app
CMD ["/usr/src/app/start.sh"]
