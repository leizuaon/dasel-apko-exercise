#!/usr/bin/env bash
set -euo pipefail

IMAGE="dasel-amd64:latest-amd64"

echo "Checking dasel is runnable..."
docker run --rm --platform linux/amd64 "$IMAGE" version

echo "Checking real JSON query behavior..."
RESULT=$(
  echo '{"name":"noa","role":"backend"}' | \
  docker run --rm -i --platform linux/amd64 "$IMAGE" query -i json 'name'
)

if [ "$RESULT" != '"noa"' ]; then
  echo "Test failed: expected '\"noa\"', got '$RESULT'"
  exit 1
fi

echo "Test passed"
