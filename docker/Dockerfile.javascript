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
COPY ./src/${FOLDER_NAME}/package*.json ./

RUN yarn install

# Copy the entire project to the container
COPY ./src/${FOLDER_NAME}/. .

# Build the project
RUN yarn build

# Expose the port the project will be served on
EXPOSE ${PORT}

# Use yarn preview to serve the build
CMD yarn preview --port $PORT --host
