#!/usr/bin/env bash

set -euo pipefail
CLUSTER=beacon
cd "$(dirname "$0")/.."

if kind get clusters | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists"
else
  kind create cluster --config cluster/kind-config.yaml
fi

kubectl config use-context "kind-$CLUSTER"
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes -L workload
