#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-}"
case "$mode" in
  ""|--all) ;;
  *) echo "usage: teardown.sh [--all]" >&2; exit 1 ;;
esac

echo "This deletes Jenkins, its home volume (build history), the app namespace and Traefik."
[ "$mode" = "--all" ] && echo "--all also deletes the Kind cluster."
read -r -p "Continue? [y/N] " answer
[ "$answer" = "y" ] || { echo "Aborted"; exit 1; }

export TF_VAR_dockerhub_token="${TF_VAR_dockerhub_token:-unused-on-destroy}"
export TF_VAR_jenkins_admin_password="${TF_VAR_jenkins_admin_password:-unused-on-destroy}"

if kind get clusters 2>/dev/null | grep -qx beacon; then
  terraform -chdir=terraform destroy -input=false -auto-approve
fi

if [ "$mode" = "--all" ]; then
  kind delete cluster --name beacon
fi

echo "Done. Kept: Git repo, Docker Hub images, terraform/terraform.tfvars, and your Docker Hub token (in your password manager)."
