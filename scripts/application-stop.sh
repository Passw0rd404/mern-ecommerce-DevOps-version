#!/bin/bash

# "|| true" because on the first deploy nothing is running yet
echo "Stopping existing process..."
pm2 delete ecommerce-backend || true
