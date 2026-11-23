#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${1:?usage: deploy.sh <image@sha256:digest | image:immutable-tag>}"
NAMESPACE="${NAMESPACE:-beacon}"
TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"
CHANGE_CAUSE="${CHANGE_CAUSE:-image=${IMAGE} commit=$(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
SMOKE_TEST="${SMOKE_TEST:-}"

case "$IMAGE" in
  *@sha256:*) ;;
  *:latest|*:latest@*) echo "refusing mutable tag 'latest': $IMAGE" >&2; exit 2 ;;
  *:*) ;;
  *) echo "image must carry a digest or an explicit tag: $IMAGE" >&2; exit 2 ;;
esac

render="$(mktemp -d)"
trap 'rm -rf "$render"' EXIT

current_image() {
  kubectl get deployment beacon -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
}

kubectl apply view-last-applied deployment/beacon -n "$NAMESPACE" -o yaml > "$render/previous-deployment.yaml" 2>/dev/null || true
previous="$(current_image)"
echo "previous image: ${previous:-<none>}"
echo "deploying:      $IMAGE"

for f in configmap service ingress deployment; do
  sed -e "s|__IMAGE__|${IMAGE}|g" -e "s|__CHANGE_CAUSE__|${CHANGE_CAUSE}|g" "k8s/$f.yaml" > "$render/$f.yaml"
done
kubectl apply -n "$NAMESPACE" -f "$render/configmap.yaml" -f "$render/service.yaml" -f "$render/ingress.yaml"
kubectl apply -n "$NAMESPACE" -f "$render/deployment.yaml"

failure=""
if ! kubectl rollout status deployment/beacon -n "$NAMESPACE" --timeout="$TIMEOUT"; then
  failure="rollout did not complete within $TIMEOUT"
elif [ -n "$SMOKE_TEST" ] && ! bash -c "$SMOKE_TEST"; then
  failure="smoke test failed"
fi

if [ -z "$failure" ]; then
  echo "deploy succeeded: $IMAGE"
  exit 0
fi

echo "DEPLOY FAILED for $IMAGE: $failure" >&2
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=beacon -o wide >&2 || true

if [ ! -s "$render/previous-deployment.yaml" ]; then
  echo "no previous known-good revision to restore (first deploy)" >&2
  exit 1
fi

echo "restoring previous known-good revision (image $previous)" >&2
sed -E "s|^(    kubernetes.io/change-cause:).*|\1 \"rollback after ${failure} of ${IMAGE}\"|" \
  "$render/previous-deployment.yaml" > "$render/rollback-deployment.yaml"
kubectl apply -n "$NAMESPACE" -f "$render/rollback-deployment.yaml" >&2
if kubectl rollout status deployment/beacon -n "$NAMESPACE" --timeout="$TIMEOUT" >&2 \
   && { [ -z "$SMOKE_TEST" ] || bash -c "$SMOKE_TEST" >&2; }; then
  echo "rollback complete: $(current_image)" >&2
else
  echo "ROLLBACK FAILED: manual intervention required" >&2
fi
exit 1
