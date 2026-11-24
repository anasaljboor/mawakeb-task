#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="${1:?usage: gitops-seed.sh <gitops-repo-url> [image@sha256:digest]}"
IMAGE="${2:-$(kubectl get deployment beacon -n beacon -o jsonpath='{.spec.template.spec.containers[0].image}')}"
APP_PATH="${GITOPS_APP_PATH:-apps/beacon}"
: "${TF_VAR_github_token:?run 'source scripts/secrets-env.sh' first}"

case "$IMAGE" in
  *@sha256:*) ;;
  *) echo "seed image must be pinned by digest: $IMAGE" >&2; exit 2 ;;
esac
IMAGE_NAME="${IMAGE%@*}"
IMAGE_DIGEST="${IMAGE#*@}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export GIT_TERMINAL_PROMPT=0
auth=(-c credential.helper= -c 'credential.helper=!f() { echo username=git; echo "password=${TF_VAR_github_token}"; }; f')

git "${auth[@]}" clone --quiet "$REPO" "$work/repo"
cd "$work/repo"
git checkout --quiet -B main
if [ -e "$APP_PATH/kustomization.yaml" ]; then
  echo "$APP_PATH already seeded in $REPO; nothing to do" >&2
  exit 1
fi

mkdir -p "$APP_PATH"
src="$OLDPWD"
for f in configmap service ingress deployment; do
  cp "$src/k8s/$f.yaml" "$APP_PATH/$f.yaml"
done

cat > "$APP_PATH/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: beacon
resources:
  - configmap.yaml
  - service.yaml
  - ingress.yaml
  - deployment.yaml
images:
  - name: beacon
    newName: ${IMAGE_NAME}
    digest: ${IMAGE_DIGEST}
EOF

cat > README.md <<'EOF'
# beacon-gitops

Desired state of the Beacon application, reconciled by ArgoCD (Application `beacon`, project `beacon`).

- `apps/beacon/` — ConfigMap, Deployment, Service, Ingress; `kustomization.yaml` pins the image by digest.
- Jenkins updates `images[0].digest` after the build, test and scan gates pass. Every deployment is a commit.
- Roll back: `git revert <commit>` and push. ArgoCD syncs the previous digest within about a minute.
- Manual edits in the cluster are reverted by ArgoCD self-heal.
EOF

kubectl kustomize "$APP_PATH" >/dev/null
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-$(git config --global user.name)}" -c user.email="${GIT_AUTHOR_EMAIL:-$(git config --global user.email)}" \
  commit --quiet -m "Seed beacon application manifests (image ${IMAGE_DIGEST:0:19})"
git "${auth[@]}" push --quiet -u origin main
echo "seeded $REPO $APP_PATH at $(git rev-parse --short HEAD) with ${IMAGE}"
