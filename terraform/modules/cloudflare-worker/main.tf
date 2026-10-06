# Cloudflare Worker module.
#
# Terraform owns the Worker itself (created empty), its custom domain and its
# route. It does not upload code: `wrangler_config_json` and `secrets` describe
# the version the deploy workflow ships with `wrangler deploy`.

locals {
  # One definition, so the Worker Terraform creates and the config Wrangler
  # deploys never disagree about logging.
  observability = {
    enabled            = true
    head_sampling_rate = 1
    logs = {
      enabled            = true
      head_sampling_rate = 1
      invocation_logs    = true
    }
  }

  # Wrangler's configuration shape, ready to serialise as wrangler.json.
  # Secrets stay out of it and travel separately in the `secrets` output.
  # Durable Object migrations are added at deploy time: which steps apply
  # depends on the Worker's live migration tag, which only Cloudflare knows.
  wrangler_config = {
    name                = var.worker_name
    main                = var.bundle_path
    no_bundle           = true
    compatibility_date  = var.compatibility_date
    compatibility_flags = var.compatibility_flags
    workers_dev         = true
    observability       = local.observability

    vars = { for name, binding in var.plain_text_bindings : name => binding.value }

    kv_namespaces = [for name, binding in var.kv_namespaces : {
      binding = name
      id      = binding.namespace_id
    }]

    d1_databases = [for name, binding in var.d1_databases : {
      binding     = name
      database_id = binding.database_id
    }]

    r2_buckets = [for name, binding in var.r2_buckets : {
      binding     = name
      bucket_name = binding.bucket_name
    }]

    # Off only while a target Worker has never been deployed: a service binding
    # needs its target deployed first.
    services = var.enable_service_bindings ? [for name, binding in var.service_bindings : {
      binding = name
      service = binding.service_name
    }] : []

    queues = {
      producers = [for name, binding in var.queue_bindings : {
        binding = name
        queue   = binding.queue_name
      }]
      consumers = [for queue_name, consumer in var.queue_consumers : {
        queue             = queue_name
        dead_letter_queue = consumer.dead_letter_queue
        max_batch_size    = consumer.max_batch_size
        max_batch_timeout = consumer.max_batch_timeout_seconds
        max_concurrency   = consumer.max_concurrency
        max_retries       = consumer.max_retries
        retry_delay       = consumer.retry_delay_seconds
      }]
    }

    # `wrangler deploy` creates a new class and binds it in one upload, so the
    # bindings no longer wait for a first deployment.
    durable_objects = {
      bindings = [for name, binding in var.durable_objects : {
        name       = name
        class_name = binding.class_name
      }]
    }

    # Always written, so removing the last schedule clears it.
    triggers = {
      crons = var.cron_triggers
    }
  }
}

resource "cloudflare_worker" "this" {
  account_id = var.account_id
  name       = var.worker_name

  # Enable workers.dev subdomain for direct access
  subdomain = {
    enabled = true
  }

  observability = local.observability
}

resource "cloudflare_workers_custom_domain" "this" {
  count = var.custom_domain != null ? 1 : 0

  account_id = var.account_id
  zone_id    = var.zone_id
  hostname   = var.custom_domain
  service    = cloudflare_worker.this.name
}

resource "cloudflare_workers_route" "this" {
  count = var.route_pattern != null ? 1 : 0

  zone_id = var.zone_id
  pattern = var.route_pattern
  script  = cloudflare_worker.this.name
}

# Versions, deployments and cron schedules now belong to `wrangler deploy`.
# Forget them without destroying the live Worker they describe.
removed {
  from = cloudflare_worker_version.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_workers_deployment.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = cloudflare_workers_cron_trigger.this
  lifecycle {
    destroy = false
  }
}
