#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="acl"
REG_NAME="acl-reg"
REG_PORT="5001"

command -v k3d >/dev/null || { echo "Please install k3d"; exit 1; }
command -v kubectl >/dev/null || { echo "Please install kubectl"; exit 1; }
command -v helm >/dev/null || { echo "Please install helm"; exit 1; }

echo "Creating k3d cluster '${CLUSTER_NAME}' with local registry '${REG_NAME}:${REG_PORT}' ..."
k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 --agents 1 \
  --registry-create "${REG_NAME}:0.0.0.0:${REG_PORT}"

echo "Cluster and registry up."
echo "Local registry endpoint: localhost:${REG_PORT}"
kubectl get nodes -o wide
