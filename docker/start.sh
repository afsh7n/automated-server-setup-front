#!/bin/sh

# Check if PORT is set, otherwise set to default
if [ -z "$PORT" ]; then
  PORT=3000
fi

# Check if FOLDER_NAME is set, otherwise default to "dist"
if [ -z "$FOLDER_NAME" ]; then
  FOLDER_NAME="dist"
fi

# Echo the port and folder name for debugging
echo "Starting serve on port ${PORT} and serving folder ${FOLDER_NAME}"

# Serve the folder on the specified port
serve -s $FOLDER_NAME -l tcp://0.0.0.0:$PORT
