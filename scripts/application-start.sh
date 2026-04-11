#!/bin/bash
set -e

APP_DIR="/home/ec2-user/ecommerce-backend"
cd $APP_DIR

# Check if PM2 is running the app already
if pm2 describe ecommerce-backend > /dev/null 2>&1; then
    echo "App is running. Performing zero-downtime reload..."
    pm2 reload ecommerce-backend --update-env
else
    echo "App is not running. Starting fresh..."
    # Points to your compiled entry point (adjust 'backend/dist/index.js' as needed)
    pm2 start backend/dist/index.js --name "ecommerce-backend"
fi

# Save the PM2 list so it persists on server reboot
pm2 save
