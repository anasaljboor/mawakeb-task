#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${1:?usage: deploy.sh <image@sha256:digest | image:immutable-tag>}"
NAMESPACE="${NAMESPACE:-beacon}"
TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"
CHANGE_CAUSE="${CHANGE_CAUSE:-image=${IMAGE} commit=$(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"

case "$IMAGE" in
  *@sha256:*) ;;
  *:latest|*:latest@*) echo "refusing mutable tag 'latest': $IMAGE" >&2; exit 2 ;;
  *:*) ;;
  *) echo "image must carry a digest or an explicit tag: $IMAGE" >&2; exit 2 ;;
esac

render="$(mktemp -d)"
trap 'rm -rf "$render"' EXIT

apply_image() {
  local image="$1" cause="$2"
  for f in configmap service ingress deployment; do
    sed -e "s|__IMAGE__|${image}|g" -e "s|__CHANGE_CAUSE__|${cause}|g" "k8s/$f.yaml" > "$render/$f.yaml"
  done
  kubectl apply -n "$NAMESPACE" -f "$render/configmap.yaml" -f "$render/service.yaml" -f "$render/ingress.yaml"
  kubectl apply -n "$NAMESPACE" -f "$render/deployment.yaml"
}

current_image() {
  kubectl get deployment beacon -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
}

previous="$(current_image)"
echo "previous image: ${previous:-<none>}"
echo "deploying:      $IMAGE"

apply_image "$IMAGE" "$CHANGE_CAUSE"
if kubectl rollout status deployment/beacon -n "$NAMESPACE" --timeout="$TIMEOUT"; then
  echo "rollout succeeded: $IMAGE"
  exit 0
fi

echo "rollout FAILED for $IMAGE" >&2
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=beacon -o wide >&2 || true
if [ -z "$previous" ] || [ "$previous" = "$IMAGE" ]; then
  echo "no previous known-good image to roll back to" >&2
  exit 1
fi

echo "rolling back to $previous" >&2
apply_image "$previous" "rollback to image=${previous} after failed image=${IMAGE}" >&2
if kubectl rollout status deployment/beacon -n "$NAMESPACE" --timeout="$TIMEOUT" >&2; then
  echo "rollback complete: $(current_image)" >&2
else
  echo "ROLLBACK FAILED: manual intervention required" >&2
fi
exit 1
