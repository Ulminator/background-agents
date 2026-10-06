# =============================================================================
# Resources handed to the deploy workflow
# =============================================================================
#
# These used to build or deploy code, or now ship inside a Wrangler config.
# `destroy = false` makes Terraform forget them without touching what is live:
# the deployed Workers, the web app's custom domain and the queue consumers stay
# in place until `wrangler deploy` takes them over.

# Worker bundles are built by build-workers.yml.
removed {
  from = null_resource.control_plane_build
  lifecycle {
    destroy = false
  }
}

removed {
  from = null_resource.slack_bot_build
  lifecycle {
    destroy = false
  }
}

removed {
  from = null_resource.github_bot_build
  lifecycle {
    destroy = false
  }
}

removed {
  from = null_resource.linear_bot_build
  lifecycle {
    destroy = false
  }
}

# The web app is built and deployed by the deploy workflow.
removed {
  from = null_resource.web_app_cloudflare_build
  lifecycle {
    destroy = false
  }
}

removed {
  from = null_resource.web_app_cloudflare_deploy
  lifecycle {
    destroy = false
  }
}

removed {
  from = null_resource.web_app_cloudflare_secrets
  lifecycle {
    destroy = false
  }
}

removed {
  from = local_file.web_app_wrangler_production
  lifecycle {
    destroy = false
  }
}

# Now a custom_domain route in the web Wrangler config.
removed {
  from = cloudflare_workers_custom_domain.web_app
  lifecycle {
    destroy = false
  }
}

# D1 migrations run in the deploy workflow.
removed {
  from = null_resource.d1_migrations
  lifecycle {
    destroy = false
  }
}

# Queue consumers ship with each Worker's Wrangler config.
removed {
  from = cloudflare_queue_consumer.image_build_finalization
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_queue_consumer.github_autofix
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_queue_consumer.slack_completion_delivery
  lifecycle {
    destroy = false
  }
}
