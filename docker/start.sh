#!/bin/sh

echo "Starting serve on port ${PORT}"
serve -s dist -l tcp://0.0.0.0:${PORT}
