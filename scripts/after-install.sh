#!/bin/bash
set -e

APP_DIR="/home/ec2-user/ecommerce-backend"
cd $APP_DIR

echo "Fetching secrets from AWS Secrets Manager..."

# 1. Fetch the JSON from Secrets Manager
# Replace 'ecommerce/prod/backend' with your actual secret name

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" --query SecretString --output text)

# 2. Parse JSON into .env format (KEY=VALUE)
echo "$SECRET_JSON" | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' > .env

# 3. Add static/non-sensitive vars that aren't in Secrets Manager
echo "NODE_ENV=production" >> .env
echo "PORT=5000" >> .env

# 4. Fix permissions so ec2-user can read the .env and run the app
chown ec2-user:ec2-user .env
chmod 600 .env
chown -R ec2-user:ec2-user "$APP_DIR"