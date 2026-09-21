#!/usr/bin/env bash
# usage: upload-frontend.sh <dist-dir> <bucket> <version>
set -euo pipefail

SRC="$1"
BUCKET="$2"
VERSION="$3"

aws s3 sync "$SRC/assets" "s3://$BUCKET/$VERSION/assets" \
  --cache-control "public,max-age=31536000,immutable" --delete

aws s3 sync "$SRC" "s3://$BUCKET/$VERSION" \
  --exclude "assets/*" --exclude "index.html" \
  --cache-control "public,max-age=3600" --delete

aws s3 cp "$SRC/index.html" "s3://$BUCKET/$VERSION/index.html" \
  --cache-control "no-cache"
