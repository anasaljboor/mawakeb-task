#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:?usage: gitops-promote.sh <image@sha256:digest>}"
: "${GITOPS_REPO:?}" "${GITOPS_TOKEN:?}" "${INGRESS_URL:?}" "${APP_HOSTNAME:?}"
APP_PATH="${GITOPS_APP_PATH:-apps/beacon}"
BRANCH="${GITOPS_BRANCH:-main}"
ARGOCD_NS="${ARGOCD_NAMESPACE:-argocd}"
APP="${ARGOCD_APP:-beacon}"
TIMEOUT="${SYNC_TIMEOUT:-300}"
MESSAGE="${COMMIT_MESSAGE:-deploy ${IMAGE_REF}}"
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

case "$IMAGE_REF" in
  *@sha256:*) ;;
  *) echo "GitOps promotion requires a digest: $IMAGE_REF" >&2; exit 2 ;;
esac

export GIT_TERMINAL_PROMPT=0
git_() {
  git -c credential.helper= -c 'credential.helper=!f() { echo username=git; echo "password=${GITOPS_TOKEN}"; }; f' \
      -c user.name=beacon-ci -c user.email=beacon-ci@users.noreply.github.com "$@"
}

app_field() {
  kubectl get application "$APP" -n "$ARGOCD_NS" -o jsonpath="$1" 2>/dev/null || true
}

wait_for() {
  local want="$1" deadline=$((SECONDS + TIMEOUT)) rev sync health
  while [ $SECONDS -lt $deadline ]; do
    rev="$(app_field '{.status.sync.revision}')"
    sync="$(app_field '{.status.sync.status}')"
    health="$(app_field '{.status.health.status}')"
    echo "argocd: revision=${rev:0:12} sync=${sync} health=${health} (waiting for ${want:0:12})"
    if [ "$rev" = "$want" ] && [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
      return 0
    fi
    if [ "$rev" = "$want" ] && [ "$health" = "Degraded" ]; then
      echo "argocd reports Degraded for ${want:0:12}" >&2
      return 1
    fi
    sleep 10
  done
  echo "timed out after ${TIMEOUT}s waiting for ${want:0:12} to be Synced and Healthy" >&2
  return 1
}

smoke() {
  local name
  name="$(sed -n 's/^ *YOUR_NAME: *//p' "$work/repo/$APP_PATH/configmap.yaml")"
  bash "$SCRIPTS/smoke-test.sh" "$INGRESS_URL" "$name" "$APP_HOSTNAME"
}

push_with_retry() {
  local i
  for i in 1 2 3; do
    git_ push --quiet origin "HEAD:$BRANCH" && return 0
    echo "push rejected (attempt $i); rebasing on $BRANCH" >&2
    git_ pull --quiet --rebase origin "$BRANCH"
  done
  return 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git_ clone --quiet --branch "$BRANCH" "$GITOPS_REPO" "$work/repo"
cd "$work/repo"

previous="$(sed -n 's/^ *digest: *//p' "$APP_PATH/kustomization.yaml")"
echo "gitops: current digest ${previous}"
echo "gitops: promoting      ${IMAGE_REF#*@}"

(cd "$APP_PATH" && kustomize edit set image "beacon=${IMAGE_REF}")
committed=false
if git diff --quiet; then
  echo "gitops: already at this digest, nothing to commit"
else
  git_ commit --quiet -am "$MESSAGE"
  push_with_retry
  committed=true
fi
promoted="$(git rev-parse HEAD)"
echo "gitops: commit ${promoted}"

if wait_for "$promoted" && smoke; then
  echo "PROMOTED ${IMAGE_REF} at gitops commit ${promoted}"
  echo "$promoted" > "$OLDPWD/gitops-commit.txt" 2>/dev/null || true
  exit 0
fi

if [ "$committed" != true ]; then
  echo "PROMOTION FAILED for ${IMAGE_REF}; this run made no commit, so there is nothing of ours to revert" >&2
  exit 1
fi
echo "PROMOTION FAILED for ${IMAGE_REF}; reverting gitops commit ${promoted:0:12}" >&2
git_ revert --no-edit "$promoted" >&2
push_with_retry >&2
reverted="$(git rev-parse HEAD)"
echo "gitops: revert commit ${reverted}" >&2
if wait_for "$reverted" >&2 && smoke >&2; then
  echo "ROLLED BACK via git revert to digest ${previous}" >&2
else
  echo "ROLLBACK FAILED: manual intervention required" >&2
fi
echo "$promoted" > "$OLDPWD/gitops-commit.txt" 2>/dev/null || true
exit 1
