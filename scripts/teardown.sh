#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=terraform/environments/local/cluster
PLATFORM=terraform/environments/local/platform

mode="${1:-}"
case "$mode" in
  ""|--all) ;;
  *) echo "usage: teardown.sh [--all]" >&2; exit 1 ;;
esac

echo "This destroys the platform stack: ArgoCD and the beacon app, Jenkins and its home volume (build history),"
echo "Prometheus/Grafana/Loki data, Traefik, secrets and namespaces."
[ "$mode" = "--all" ] && echo "--all also destroys the Kind cluster stack."
read -r -p "Continue? [y/N] " answer
[ "$answer" = "y" ] || { echo "Aborted"; exit 1; }

export TF_VAR_registry_token="${TF_VAR_registry_token:-unused-on-destroy}"
export TF_VAR_jenkins_admin_password="${TF_VAR_jenkins_admin_password:-unused-on-destroy}"
export TF_VAR_github_token="${TF_VAR_github_token:-unused-on-destroy}"
export TF_VAR_grafana_admin_password="${TF_VAR_grafana_admin_password:-unused-on-destroy}"

if [ -f "$PLATFORM/terraform.tfstate" ] && terraform -chdir="$PLATFORM" state list >/dev/null 2>&1; then
  if kubectl get application beacon -n argocd >/dev/null 2>&1; then
    echo "Deleting the ArgoCD Application first so its finalizer is processed while ArgoCD still runs"
    kubectl delete application beacon -n argocd --wait=true --timeout=180s
  fi
  terraform -chdir="$PLATFORM" destroy -input=false -auto-approve
fi

if [ "$mode" = "--all" ] && [ -f "$CLUSTER/terraform.tfstate" ]; then
  terraform -chdir="$CLUSTER" destroy -input=false -auto-approve
fi

echo "Done. Kept: this Git repo, the beacon-gitops repo (desired state and deploy history), registry images,"
echo "terraform.tfvars files, and your registry and GitHub tokens (in your password manager)."
