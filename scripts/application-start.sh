#!/bin/bash
set -euo pipefail

APP_DIR="/home/ec2-user/ecommerce-backend"
cd "$APP_DIR"

# Put every variable from .env into the shell, so PM2 hands them to the app.
# tracing.js needs the OTEL_* values before the app starts.
set -a
source .env
set +a

# Remove any old entry, then start fresh from the config file in the repo
pm2 delete ecommerce-backend > /dev/null 2>&1 || true
pm2 start ecosystem.config.cjs
