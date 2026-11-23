#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in docker kind kubectl helm terraform openssl; do
  command -v "$tool" >/dev/null || { echo "missing prerequisite: $tool" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

[ -f terraform/terraform.tfvars ] || {
  echo "terraform/terraform.tfvars not found: copy terraform/terraform.tfvars.example and fill it in" >&2
  exit 1
}

./scripts/cluster-up.sh

source scripts/secrets-env.sh

terraform -chdir=terraform init -input=false
terraform -chdir=terraform plan -input=false -out=tfplan
read -r -p "Apply this plan? [y/N] " answer
[ "$answer" = "y" ] || { rm -f terraform/tfplan; echo "Aborted"; exit 1; }
terraform -chdir=terraform apply -input=false tfplan
rm -f terraform/tfplan
chmod 600 terraform/terraform.tfstate*

if terraform -chdir=terraform plan -input=false -detailed-exitcode >/dev/null; then
  echo "Second plan: no changes"
else
  echo "Second plan is not clean: run 'terraform -chdir=terraform plan' and review" >&2
  exit 1
fi

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

failed=0
check_url Jenkins "$(terraform -chdir=terraform output -raw jenkins_url)/login" || failed=1
check_url ArgoCD  "$(terraform -chdir=terraform output -raw argocd_url)/" || failed=1
check_url Grafana "${GRAFANA_URL:-http://grafana.127.0.0.1.nip.io}/login" || failed=1

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
