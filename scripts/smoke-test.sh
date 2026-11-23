#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?usage: smoke-test.sh <base-url> [expected-name] [host-header]}"
EXPECTED_NAME="${2:-anas}"
HOST_HEADER="${3:-}"

args=(-s --max-time 5)
[ -n "$HOST_HEADER" ] && args+=(-H "Host: $HOST_HEADER")

for _ in $(seq 1 20); do
  body="$(curl "${args[@]}" "$BASE_URL/" || true)"
  [ "$body" = "hello $EXPECTED_NAME" ] && break
  sleep 3
done
echo "GET /                -> $body"
[ "$body" = "hello $EXPECTED_NAME" ] || { echo "greeting check FAILED (expected 'hello $EXPECTED_NAME')" >&2; exit 1; }

health="$(curl "${args[@]}" "$BASE_URL/actuator/health" || true)"
echo "GET /actuator/health -> $health"
case "$health" in
  *'"status":"UP"'*) ;;
  *) echo "health check FAILED" >&2; exit 1 ;;
esac

echo "smoke test passed"
