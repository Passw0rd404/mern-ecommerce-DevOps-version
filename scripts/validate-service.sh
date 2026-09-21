#!/bin/bash
set -e

MAX_ATTEMPTS=24
WAIT_SECONDS=5

echo "Waiting for service to become ready..."

for i in $(seq 1 $MAX_ATTEMPTS)
do
  HTTP_CODE=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:5000/api/health/ready || true)

  if [ "$HTTP_CODE" == "200" ]; then
    echo "Service is ready (attempt $i)!"
    exit 0
  fi

  echo "Attempt $i/$MAX_ATTEMPTS failed with code $HTTP_CODE. Retrying in ${WAIT_SECONDS}s..."
  sleep $WAIT_SECONDS
done

echo "Service failed to become ready after $MAX_ATTEMPTS attempts. Last code: $HTTP_CODE"
pm2 logs ecommerce-backend --lines 50 --nostream
exit 1
