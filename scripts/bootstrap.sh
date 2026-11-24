#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=terraform/environments/local/cluster
PLATFORM=terraform/environments/local/platform

for tool in docker kubectl helm terraform openssl curl jq; do
  command -v "$tool" >/dev/null || { echo "missing prerequisite: $tool" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

[ -f "$PLATFORM/terraform.tfvars" ] || {
  echo "$PLATFORM/terraform.tfvars not found: copy terraform.tfvars.example next to it and fill it in" >&2
  exit 1
}

apply_stack() {
  local dir="$1" name="$2" answer
  terraform -chdir="$dir" init -input=false
  terraform -chdir="$dir" plan -input=false -out=tfplan
  read -r -p "Apply the $name plan? [y/N] " answer
  [ "$answer" = "y" ] || { rm -f "$dir/tfplan"; echo "Aborted"; exit 1; }
  terraform -chdir="$dir" apply -input=false tfplan
  rm -f "$dir/tfplan"
  chmod 600 "$dir"/terraform.tfstate*
  if terraform -chdir="$dir" plan -input=false -detailed-exitcode >/dev/null; then
    echo "$name second plan: no changes"
  else
    echo "$name second plan is not clean: run 'terraform -chdir=$dir plan' and review" >&2
    exit 1
  fi
}

apply_stack "$CLUSTER" "cluster"
kubectl config use-context "$(terraform -chdir="$CLUSTER" output -raw context_name)" >/dev/null

source scripts/secrets-env.sh
for v in TF_VAR_registry_token TF_VAR_github_token TF_VAR_jenkins_admin_password TF_VAR_grafana_admin_password; do
  [ -n "${!v:-}" ] || { echo "$v is empty: rerun and paste the token at the prompt" >&2; exit 1; }
done
apply_stack "$PLATFORM" "platform"

check_url() {
  local name="$1" url="$2" code=000
  for _ in $(seq 1 30); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)"
    [ "$code" = "200" ] && break
    sleep 2
  done
  printf '%-8s %s (HTTP %s)\n' "$name" "$url" "$code"
  [ "$code" = "200" ] || { echo "$name is not reachable through the ingress: see Troubleshooting in RUNBOOK.md" >&2; return 1; }
}

urls="$(terraform -chdir="$PLATFORM" output -json urls)"
failed=0
check_url Jenkins "$(jq -r .jenkins <<<"$urls")/login" || failed=1
check_url ArgoCD  "$(jq -r .argocd <<<"$urls")/" || failed=1
check_url Grafana "$(jq -r .grafana <<<"$urls" | sed 's|/d/beacon$||')/login" || failed=1

app_state="$(kubectl get application beacon -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)"
app_error="$(kubectl get application beacon -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null || true)"
echo "ArgoCD   application beacon: ${app_state:-unknown}"
if printf '%s' "$app_error" | grep -qiE 'does not exist|not found|empty'; then
  echo "The GitOps repository is not seeded yet: run scripts/gitops-seed.sh <repo-url> <image@sha256:digest> (see RUNBOOK.md)" >&2
  failed=1
fi

builds="$(kubectl exec -n jenkins jenkins-0 -c jenkins -- sh -c \
  'curl -s -u "$(cat /run/secrets/additional/chart-admin-username):$(cat /run/secrets/additional/chart-admin-password)" "http://localhost:8080/job/beacon/api/json?tree=builds%5Bnumber%5D"' 2>/dev/null || true)"
if printf '%s' "$builds" | grep -q '"builds":\[\]'; then
  echo "Jenkins  queueing the first build of job beacon (SCM polling only starts after one build)"
  kubectl exec -n jenkins jenkins-0 -c jenkins -- sh -c '
    U=$(cat /run/secrets/additional/chart-admin-username); P=$(cat /run/secrets/additional/chart-admin-password); J=$(mktemp)
    C=$(curl -s -c "$J" -u "$U:$P" "http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")
    curl -s -o /dev/null -w "Jenkins  build queued (HTTP %{http_code})\n" -b "$J" -u "$U:$P" -H "$C" -X POST http://localhost:8080/job/beacon/build
    rm -f "$J"'
fi

exit "$failed"
