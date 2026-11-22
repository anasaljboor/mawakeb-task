#!/usr/bin/env bash
# Scan a container image with Trivy (OS packages + Java libraries).
# Fails (non-zero exit) on any finding or scanner error.
# Usage: scripts/scan.sh <image> [output-dir]
set -euo pipefail
IMAGE="${1:?usage: scan.sh <image> [output-dir]}"
OUT="${2:-reports}"
mkdir -p "$OUT"

docker image inspect --format '{{.Id}}' "$IMAGE" > "$OUT/image-id.txt"
rm -f "$OUT/trivy.json" "$OUT/trivy-version.json"   # never show a stale report

status=0
trivy image \
  --scanners vuln \
  --pkg-types os,library \
  --exit-code 1 \
  --format json --output "$OUT/trivy.json" \
  "$IMAGE" || status=$?

# Record scanner + DB version AFTER the scan, so it reflects the DB actually used
trivy version --format json > "$OUT/trivy-version.json"

# Human-readable summary (only if the JSON report was produced)
[ -s "$OUT/trivy.json" ] && trivy convert --scanners vuln --format table "$OUT/trivy.json"

exit "$status"
