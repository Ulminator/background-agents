mock_provider "cloudflare" {}
mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        hash = "test-source-hash"
      }
    }
  }
}
mock_provider "local" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "vercel" {}

variables {
  cloudflare_api_token        = "test-cloudflare-token"
  cloudflare_account_id       = "test-account"
  cloudflare_worker_subdomain = "test-account"
  github_app_id               = "1"
  github_app_private_key      = "test-private-key"
  github_app_installation_id  = "1"
  anthropic_api_key           = "test-anthropic-key"
  token_encryption_key        = "test-token-key"
  repo_secrets_encryption_key = "test-repo-key"
  nextauth_secret             = "test-browser-auth-secret-with-32-characters"
  deployment_name             = "manifest-test"

  modal_token_id     = "test-modal-token-id"
  modal_token_secret = "test-modal-token-secret"
  modal_workspace    = "test-workspace"
  modal_api_secret   = "test-modal-api-secret"

  web_platform = "cloudflare"
  project_root = "../../../"

  # The GitHub bot puts the autofix queue on the control plane's consumer list.
  enable_github_bot     = true
  github_webhook_secret = "test-github-webhook-secret"
  github_bot_username   = "test-bot[bot]"
  enable_slack_bot      = false

  github_client_id     = "github-id"
  github_client_secret = "github-secret"
  allowed_users        = "octocat"
}

# The Wrangler configs embed D1 and KV IDs, which are only known after apply.
override_resource {
  target          = cloudflare_d1_database.main
  override_during = plan
  values = {
    id = "d1-test-id"
  }
}

override_resource {
  target          = module.session_index_kv.cloudflare_workers_kv_namespace.this
  override_during = plan
  values = {
    id = "kv-test-id"
  }
}

run "control_plane_manifest_carries_everything_wrangler_needs" {
  command = plan

  assert {
    condition     = nonsensitive(output.deploy_manifest.d1_database_name) == "open-inspect-manifest-test"
    error_message = "The deploy workflow needs the D1 name to run migrations."
  }

  assert {
    condition = (
      nonsensitive(jsondecode(output.deploy_manifest.workers["control-plane"].config_json)).main == "packages/control-plane/dist/index.js" &&
      nonsensitive(jsondecode(output.deploy_manifest.workers["control-plane"].config_json)).d1_databases[0].database_id == "d1-test-id"
    )
    error_message = "The control-plane config must point at its bundle and bind the D1 database."
  }

  # No enable_durable_object_bindings phase: the class binds on the first deploy.
  assert {
    condition     = nonsensitive(jsondecode(output.deploy_manifest.workers["control-plane"].config_json)).durable_objects.bindings[0].class_name == "SessionDO"
    error_message = "SessionDO must be bound from the first deploy."
  }

  assert {
    condition = (
      contains(
        [for consumer in nonsensitive(jsondecode(output.deploy_manifest.workers["control-plane"].config_json)).queues.consumers : consumer.queue],
        "open-inspect-image-build-finalization-manifest-test"
      ) &&
      contains(
        [for consumer in nonsensitive(jsondecode(output.deploy_manifest.workers["control-plane"].config_json)).queues.consumers : consumer.queue],
        "open-inspect-github-autofix-manifest-test"
      )
    )
    error_message = "The control plane must consume the image-build and autofix queues."
  }

  assert {
    condition     = !strcontains(nonsensitive(output.deploy_manifest.workers["control-plane"].config_json), "test-token-key")
    error_message = "Secrets must not leak into the Wrangler config."
  }
}

run "web_manifest_without_a_custom_domain_serves_workers_dev" {
  command = plan

  assert {
    condition = (
      nonsensitive(jsondecode(output.deploy_manifest.web.config_json)).workers_dev &&
      length(nonsensitive(jsondecode(output.deploy_manifest.web.config_json)).routes) == 0 &&
      nonsensitive(output.deploy_manifest.web.build_env.NEXT_PUBLIC_WS_URL) == "wss://open-inspect-control-plane-manifest-test.test-account.workers.dev"
    )
    error_message = "Without a custom domain the web Worker serves workers.dev, built against the control-plane WebSocket URL."
  }
}

run "web_custom_domain_ships_as_a_wrangler_route" {
  command = plan

  variables {
    cloudflare_custom_domain = "app.example.com"
    cloudflare_zone_id       = "zone-test-id"
  }

  assert {
    condition = (
      !nonsensitive(jsondecode(output.deploy_manifest.web.config_json)).workers_dev &&
      nonsensitive(jsondecode(output.deploy_manifest.web.config_json)).routes[0].pattern == "app.example.com" &&
      nonsensitive(jsondecode(output.deploy_manifest.web.config_json)).routes[0].custom_domain
    )
    error_message = "A custom domain becomes a custom_domain route and turns workers.dev off."
  }
}
