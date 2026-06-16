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

echo "Checking CVE-2026-33320 regression behavior..."
YAML_BOMB='a: &a ["lol","lol","lol","lol","lol","lol","lol","lol","lol"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]
e: &e [*d,*d,*d,*d,*d,*d,*d,*d,*d]
f: &f [*e,*e,*e,*e,*e,*e,*e,*e,*e]
g: &g [*f,*f,*f,*f,*f,*f,*f,*f,*f]
h: &h [*g,*g,*g,*g,*g,*g,*g,*g,*g]
i: &i [*h,*h,*h,*h,*h,*h,*h,*h,*h]'

set +e
CVE_ERR="$({
  printf '%s\n' "$YAML_BOMB" | \
  docker run --rm -i --platform linux/amd64 --stop-timeout 1 "$IMAGE" query -i yaml 'i' >/dev/null
} 2>&1)"
CVE_STATUS=$?
set -e

if [ "$CVE_STATUS" -eq 0 ]; then
  echo "Test failed: CVE regression payload unexpectedly succeeded"
  exit 1
fi

echo "$CVE_ERR" | grep -Eq 'yaml expansion (depth|budget) exceeded'

echo "Test passed"
