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

url="$(terraform -chdir=terraform output -raw jenkins_url)"
code="$(curl -s -o /dev/null -w '%{http_code}' "$url/login")"
echo "Jenkins: $url (HTTP $code)"
[ "$code" = "200" ]
