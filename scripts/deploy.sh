#!/usr/bin/env bash
set -euo pipefail

# Deploy Postgres (init SQL from repo file)
helm upgrade --install postgres ./helm/postgres \
  --namespace default \
  -f ./helm/postgres/values.yaml \
  --set-file initSql=./db/init.sql

# Get current image tag (commit) if possible
TAG="$(git rev-parse --short HEAD || echo 'latest')"

# Deploy API, injecting mapping YAML from repo file
helm upgrade --install api ./helm/api \
  --namespace default \
  -f ./helm/api/values.yaml \
  --set "image.tag=${TAG}" \
  --set-file mappingYaml=./config/mappings.yml

echo "Deployments applied."
kubectl get pods -l app=postgres -o wide
kubectl get pods -l app=acl-api -o wide
kubectl get svc postgres-service api-service
