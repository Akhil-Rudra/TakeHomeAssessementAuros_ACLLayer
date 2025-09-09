#!/usr/bin/env bash
set -euo pipefail

branch="main"
echo "Starting local GitOps loop watching branch: ${branch}"
echo "(commit to main to trigger actions; Ctrl+C to stop)"
prev_head="$(git rev-parse ${branch})"

while true; do
  sleep 3
  # In a real setup you'd also 'git fetch' and compare with origin/main.
  head="$(git rev-parse ${branch})" || continue
  if [[ "$head" != "$prev_head" ]]; then
    echo "Detected new commit: $head"
    changed="$(git diff --name-only ${prev_head} ${head} || true)"
    echo "Changed files:"
    echo "$changed"

    only_config=true
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if [[ "$f" != config/* ]]; then
        only_config=false
        break
      fi
    done <<< "$changed"

    if $only_config; then
      echo "Only config/ changed → refreshing ConfigMap + restarting API"
      # Re-run helm upgrade to update ConfigMap and trigger rollout via checksum
      helm upgrade --install api ./helm/api \
        -f ./helm/api/values.yaml \
        --set-file mappingYaml=./config/mappings.yml
      kubectl rollout restart deploy/api-deployment
    else
      # Detect if postgres chart changed
      if echo "$changed" | grep -q '^helm/postgres/'; then
        echo "Postgres IaC changed → helm upgrade postgres"
        helm upgrade --install postgres ./helm/postgres \
          -f ./helm/postgres/values.yaml \
          --set-file initSql=./db/init.sql
      fi

      # Build + push + deploy API for any app/chart changes
      ./scripts/build_and_push.sh
      helm upgrade --install api ./helm/api \
        -f ./helm/api/values.yaml \
        --set "image.tag=$(git rev-parse --short ${branch})" \
        --set-file mappingYaml=./config/mappings.yml
    fi

    prev_head="$head"
    echo "Update complete for $head"
  fi
done
