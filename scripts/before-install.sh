#!/bin/bash
set -e

# Clean up existing files to prevent permission conflicts
# We keep the directory but clear contents
APP_DIR="/home/ec2-user/ecommerce-backend"
if [ -d "$APP_DIR" ]; then
    echo "Cleaning up existing directory..."
    rm -rf ${APP_DIR}/*
else
    mkdir -p "$APP_DIR"
fi

chown -R ec2-user:ec2-user "$APP_DIR"