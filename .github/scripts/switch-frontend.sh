#!/usr/bin/env bash
# usage: switch-frontend.sh <version>   (needs KVS_ARN and SITE_URL in the environment)
set -euo pipefail

VERSION="$1"

ETAG=$(aws cloudfront-keyvaluestore describe-key-value-store \
  --kvs-arn "$KVS_ARN" --query ETag --output text)

aws cloudfront-keyvaluestore put-key \
  --kvs-arn "$KVS_ARN" --key version --value "$VERSION" --if-match "$ETAG"

# Store updates reach the edge in seconds. Wait until the site serves the new build.
LIVE=""
for _ in $(seq 1 30); do
  LIVE=$(curl -fsS "$SITE_URL/version.txt" 2>/dev/null || true)
  if [ "$LIVE" = "$VERSION" ]; then
    echo "Live version is now $VERSION"
    exit 0
  fi
  sleep 5
done

echo "Site did not report $VERSION within 150s (last saw: '${LIVE:-nothing}')"
exit 1
