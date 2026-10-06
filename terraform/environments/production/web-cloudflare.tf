# =============================================================================
# Web App — Cloudflare Workers via OpenNext (when web_platform = "cloudflare")
# =============================================================================
#
# Terraform no longer builds or deploys the web app. It describes the
# deployment here, and the deploy workflow builds the OpenNext bundle with
# `build_env` and ships it with `wrangler deploy`.
#
# The custom domain is part of the Wrangler config rather than a Terraform
# resource: Wrangler creates the web Worker on its first deploy, so on a fresh
# install there is no Worker for a Terraform-managed domain to attach to yet.

locals {
  web_cloudflare_deploy = var.web_platform == "cloudflare" ? {
    config_json = jsonencode({
      name                = local.web_worker_name
      main                = ".open-next/worker.js"
      compatibility_date  = "2025-08-15"
      compatibility_flags = ["nodejs_compat", "global_fetch_strictly_public"]
      # Keep-names makes esbuild emit __name() calls, which leak into
      # next-themes' inline script and throw in the browser.
      keep_names = false

      # A custom-domain deployment has one canonical browser origin.
      workers_dev = !local.web_custom_domain_enabled
      routes = local.web_custom_domain_enabled ? [{
        pattern       = local.web_custom_domain
        zone_id       = local.web_custom_domain_zone_id
        custom_domain = true
      }] : []

      vars = {
        CONTROL_PLANE_URL            = local.control_plane_url
        NEXT_PUBLIC_WS_URL           = local.ws_url
        NEXT_PUBLIC_SANDBOX_PROVIDER = var.sandbox_provider
        NEXT_PUBLIC_APP_NAME         = var.app_name
        NEXT_PUBLIC_APP_ICON_URL     = var.app_icon_url
      }

      assets = {
        directory = ".open-next/assets"
        binding   = "ASSETS"
      }

      services = [{
        binding = "CONTROL_PLANE_WORKER"
        service = "open-inspect-control-plane-${local.name_suffix}"
      }]
    })

    # NEXT_PUBLIC_* values are inlined into the client bundle at build time.
    build_env = {
      NEXT_PUBLIC_WS_URL           = local.ws_url
      NEXT_PUBLIC_SANDBOX_PROVIDER = var.sandbox_provider
      NEXT_PUBLIC_APP_NAME         = var.app_name
      NEXT_PUBLIC_APP_ICON_URL     = var.app_icon_url
    }

    secrets = {
      SERVICE_AUTH_SECRET = random_password.service_auth_secret_web.result
    }
  } : null
}
