#!/bin/sh
set -eu
IMAGE="${1:?usage: scan.sh <image> [output-dir]}"
OUT="${2:-reports}"
mkdir -p "$OUT"
rm -f "$OUT/trivy.json" "$OUT/trivy-version.json" "$OUT/image-id.txt"

status=0
trivy image \
  --scanners vuln \
  --pkg-types os,library \
  --exit-code 1 \
  --format json --output "$OUT/trivy.json" \
  "$IMAGE" || status=$?

trivy version --format json > "$OUT/trivy-version.json"

if [ -s "$OUT/trivy.json" ]; then
  sed -n 's/.*"ImageID": *"\([^"]*\)".*/\1/p' "$OUT/trivy.json" | head -n 1 > "$OUT/image-id.txt"
  trivy convert --scanners vuln --format table "$OUT/trivy.json"
fi

exit "$status"
