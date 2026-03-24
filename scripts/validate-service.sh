#!/bin/bash
set -e

MAX_ATTEMPTS=10
WAIT_SECONDS=5

echo "Waiting for service to become healthy..."

for i in $(seq 1 $MAX_ATTEMPTS)
do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/health || echo "000")

  if [ "$HTTP_CODE" == "200" ]; then
    echo "Service is healthy (attempt $i)!"
    exit 0
  fi

  echo "Attempt $i/$MAX_ATTEMPTS failed with code $HTTP_CODE. Retrying in ${WAIT_SECONDS}s..."
  sleep $WAIT_SECONDS
done

echo "Service failed to become healthy after $MAX_ATTEMPTS attempts. Last code: $HTTP_CODE"
pm2 logs ecommerce-backend --lines 50 --nostream
exit 1