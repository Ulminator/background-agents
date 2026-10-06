#!/usr/bin/env bash
# Deploys Worker code and the Cloudflare web app from Terraform's deploy manifest.
#
#   bash scripts/deploy-cloudflare.sh <manifest.json>
#
# <manifest.json> is `terraform output -json deploy_manifest`. Run from the
# repository root after `terraform apply`, with the Worker bundles built
# (packages/<package>/dist/index.js) and CLOUDFLARE_API_TOKEN and
# CLOUDFLARE_ACCOUNT_ID set. The deploy workflow runs this same script.
set -euo pipefail

manifest="${1:?Usage: deploy-cloudflare.sh <manifest.json>}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN must be set}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID must be set}"

# Rendered configs hold secrets; keep them out of the checkout and remove them.
configs="$(mktemp -d)"
trap 'rm -rf "$configs"' EXIT

# Wrangler applies only the migrations after the Worker's live tag, and
# deployments sit on different tags, so the rendered list depends on it.
name="$(jq -r '.workers["control-plane"].config_json | fromjson | .name' "$manifest")"
scripts="$(curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts")"
tag="$(jq -r --arg name "$name" '.result[] | select(.id == $name) | .migration_tag // empty' <<<"$scripts")"
echo "Control plane migration tag: ${tag:-none (fresh install)}"

node scripts/render-wrangler-configs.mjs "$manifest" "$configs" --control-plane-migration-tag "$tag"

bash scripts/d1-migrate.sh "$(jq -r .d1_database_name "$manifest")" terraform/d1/migrations

# The control plane first: the bots and the web app bind to it.
for pkg in control-plane slack-bot github-bot linear-bot; do
  [ -f "$configs/$pkg/wrangler.json" ] || continue
  echo "Deploying $pkg"
  npx wrangler deploy --config "$configs/$pkg/wrangler.json" --secrets-file "$configs/$pkg/secrets.json"
done

if [ -f "$configs/web/wrangler.json" ]; then
  echo "Building and deploying the web app"
  (
    set -a
    # shellcheck disable=SC1091 # Rendered at runtime.
    . "$configs/web/build.env"
    set +a
    npm run build -w @open-inspect/shared
    npm run build:cloudflare -w @open-inspect/web
  )
  npx wrangler deploy --config "$configs/web/wrangler.json"
  # Also retires secrets earlier releases set.
  WORKER_NAME="$(jq -r .name "$configs/web/wrangler.json")" \
    SERVICE_AUTH_SECRET="$(jq -r .SERVICE_AUTH_SECRET "$configs/web/secrets.json")" \
    bash scripts/wrangler-secrets.sh
fi
