#!/bin/bash
set -euo pipefail

APP_DIR="/home/ec2-user/ecommerce-backend"
cd "$APP_DIR"

# Load SECRET_NAME (the launch template user data writes it to /etc/environment)
# user data writes SECRET_NAME at first boot; wait for it if the deploy starts first
for i in $(seq 1 30); do
  if [ -r /etc/environment ]; then
    set -a
    . /etc/environment
    set +a
  fi
  [ -n "${SECRET_NAME:-}" ] && break
  sleep 2
done
: "${SECRET_NAME:?SECRET_NAME is not set in /etc/environment}"

# Region (IMDSv2: get a token first)
TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
REGION=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

echo "Fetching secrets from AWS Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" --region "$REGION" \
  --query SecretString --output text)

# One KEY='value' line per secret. Single quotes keep any character safe.
echo "$SECRET_JSON" | python3 -c '
import sys, json, shlex
for k, v in json.load(sys.stdin).items():
    print(f"{k}={shlex.quote(str(v))}")
' > .env

chown -R ec2-user:ec2-user "$APP_DIR"
chmod 600 .env

echo "Configuring Grafana Alloy..."
set -a
. .env
set +a

sudo sed \
  -e "s|__GRAFANA_OTLP_ENDPOINT__|${GRAFANA_OTLP_ENDPOINT}|g" \
  -e "s|__GRAFANA_OTLP_INSTANCE_ID__|${GRAFANA_OTLP_INSTANCE_ID}|g" \
  -e "s|__GRAFANA_OTLP_TOKEN__|${GRAFANA_OTLP_TOKEN}|g" \
  /etc/alloy/config.alloy.tmpl | sudo tee /etc/alloy/config.alloy > /dev/null

sudo chmod 600 /etc/alloy/config.alloy
sudo systemctl restart alloy
