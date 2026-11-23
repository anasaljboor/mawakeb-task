#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-}"
case "$mode" in
  ""|--all) ;;
  *) echo "usage: teardown.sh [--all]" >&2; exit 1 ;;
esac

echo "This deletes everything Terraform created: ArgoCD and the beacon app, Jenkins and its home volume"
echo "(build history), Prometheus/Grafana/Loki data, Traefik, secrets and namespaces."
[ "$mode" = "--all" ] && echo "--all also deletes the Kind cluster."
read -r -p "Continue? [y/N] " answer
[ "$answer" = "y" ] || { echo "Aborted"; exit 1; }

export TF_VAR_dockerhub_token="${TF_VAR_dockerhub_token:-unused-on-destroy}"
export TF_VAR_jenkins_admin_password="${TF_VAR_jenkins_admin_password:-unused-on-destroy}"
export TF_VAR_github_token="${TF_VAR_github_token:-unused-on-destroy}"
export TF_VAR_grafana_admin_password="${TF_VAR_grafana_admin_password:-unused-on-destroy}"

if kind get clusters 2>/dev/null | grep -qx beacon; then
  if kubectl get application beacon -n argocd >/dev/null 2>&1; then
    echo "Deleting the ArgoCD Application first so its finalizer is processed while ArgoCD still runs"
    kubectl delete application beacon -n argocd --wait=true --timeout=180s
  fi
  terraform -chdir=terraform destroy -input=false -auto-approve
fi

if [ "$mode" = "--all" ]; then
  kind delete cluster --name beacon
fi

echo "Done. Kept: this Git repo, the beacon-gitops repo (desired state and deploy history), Docker Hub images,"
echo "terraform/terraform.tfvars, and your Docker Hub and GitHub tokens (in your password manager)."
