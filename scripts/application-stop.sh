#!/bin/bash

# We use || true because if the app isn't running (first deploy), 

echo "Stopping existing process..."
pm2 stop ecommerce-backend || true