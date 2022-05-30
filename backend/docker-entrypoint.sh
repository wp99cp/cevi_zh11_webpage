#!/bin/bash

set -e

# Start Backend Server
echo "Start Backend Server"
exec gunicorn --workers 1 --threads 1 --timeout 120 --reload --bind :$PORT app:app
