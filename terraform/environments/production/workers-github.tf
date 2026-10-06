# =============================================================================
# GitHub Bot Worker
# =============================================================================

resource "cloudflare_queue" "github_autofix" {
  count = var.enable_github_bot ? 1 : 0

  account_id = var.cloudflare_account_id
  queue_name = "open-inspect-github-autofix-${local.name_suffix}"
}

resource "cloudflare_queue" "github_autofix_dlq" {
  count = var.enable_github_bot ? 1 : 0

  account_id = var.cloudflare_account_id
  queue_name = "open-inspect-github-autofix-dlq-${local.name_suffix}"
}

module "github_bot_worker" {
  count  = var.enable_github_bot ? 1 : 0
  source = "../../modules/cloudflare-worker"

  account_id       = var.cloudflare_account_id
  worker_name      = "open-inspect-github-bot-${local.name_suffix}"
  worker_subdomain = var.cloudflare_worker_subdomain
  bundle_path      = local.github_bot_bundle_path

  kv_namespaces = {
    GITHUB_KV = {
      namespace_id = module.github_kv[0].namespace_id
    }
  }

  service_bindings = {
    CONTROL_PLANE = {
      service_name = "open-inspect-control-plane-${local.name_suffix}"
    }
  }

  enable_service_bindings = var.enable_service_bindings

  queue_bindings = {
    AUTOFIX_QUEUE = {
      queue_name = cloudflare_queue.github_autofix[0].queue_name
    }
  }

  plain_text_bindings = {
    DEPLOYMENT_NAME     = { value = var.deployment_name }
    APP_NAME            = { value = var.app_name }
    DEFAULT_MODEL       = { value = var.github_bot_default_model }
    GITHUB_BOT_USERNAME = { value = var.github_bot_username }
  }

  secrets = {
    GITHUB_APP_ID              = { value = var.github_app_id }
    GITHUB_APP_PRIVATE_KEY     = { value = var.github_app_private_key }
    GITHUB_APP_INSTALLATION_ID = { value = var.github_app_installation_id }
    GITHUB_WEBHOOK_SECRET      = { value = var.github_webhook_secret }
    SERVICE_AUTH_SECRET        = { value = random_password.service_auth_secret_github_bot.result }
  }

  compatibility_date  = "2024-09-23"
  compatibility_flags = ["nodejs_compat"]
}
