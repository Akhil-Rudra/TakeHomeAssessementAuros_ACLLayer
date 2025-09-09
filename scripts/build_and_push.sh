#!/usr/bin/env bash
set -euo pipefail

REGISTRY="localhost:5001"
IMAGE="${REGISTRY}/acl-api"
TAG="$(git rev-parse --short HEAD || echo 'dev')"

echo "Building ${IMAGE}:${TAG} ..."
docker build -t "${IMAGE}:${TAG}" -f api/Dockerfile .
docker tag "${IMAGE}:${TAG}" "${IMAGE}:latest"

echo "Pushing to local registry ${REGISTRY} ..."
docker push "${IMAGE}:${TAG}"
docker push "${IMAGE}:latest"

echo "Done: ${IMAGE}:${TAG}"
