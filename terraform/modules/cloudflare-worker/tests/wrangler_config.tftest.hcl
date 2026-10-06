mock_provider "cloudflare" {}

variables {
  account_id       = "test-account"
  worker_name      = "wrangler-config-test"
  worker_subdomain = "test-account"
  bundle_path      = "packages/test/dist/index.js"

  plain_text_bindings = { APP_NAME = { value = "Test" } }
  secrets             = { API_KEY = { value = "s3cret" } }
  service_bindings    = { CONTROL_PLANE = { service_name = "control-plane" } }
  durable_objects     = { SESSION = { class_name = "SessionDO" } }
  cron_triggers       = ["* * * * *"]

  queue_consumers = {
    jobs = {
      dead_letter_queue         = "jobs-dlq"
      max_batch_size            = 1
      max_batch_timeout_seconds = 1
      max_retries               = 4
      retry_delay_seconds       = 30
    }
  }
}

run "config_points_wrangler_at_the_prebuilt_bundle" {
  command = plan

  assert {
    condition = (
      jsondecode(output.wrangler_config_json).main == "packages/test/dist/index.js" &&
      jsondecode(output.wrangler_config_json).no_bundle
    )
    error_message = "Wrangler must upload the prebuilt bundle as-is."
  }
}

run "secrets_travel_apart_from_the_config" {
  command = plan

  assert {
    condition     = !strcontains(output.wrangler_config_json, "s3cret") && output.secrets == { API_KEY = "s3cret" }
    error_message = "Secrets belong in the secrets output, never in the Wrangler config."
  }

  assert {
    condition     = jsondecode(output.wrangler_config_json).vars == { APP_NAME = "Test" }
    error_message = "Plain-text bindings become Wrangler vars."
  }
}

# The class and its binding ship in one upload, so there is no binding switch.
run "durable_objects_bind_without_a_bootstrap_flag" {
  command = plan

  assert {
    condition = (
      jsondecode(output.wrangler_config_json).durable_objects.bindings[0].class_name == "SessionDO" &&
      !contains(keys(jsondecode(output.wrangler_config_json)), "migrations")
    )
    error_message = "Durable Objects bind immediately; migrations are added at deploy time."
  }
}

run "queue_consumers_use_wrangler_seconds" {
  command = plan

  assert {
    condition = (
      jsondecode(output.wrangler_config_json).queues.consumers[0].queue == "jobs" &&
      jsondecode(output.wrangler_config_json).queues.consumers[0].max_batch_timeout == 1 &&
      jsondecode(output.wrangler_config_json).queues.consumers[0].retry_delay == 30
    )
    error_message = "Queue consumer settings must map to Wrangler's keys and units."
  }
}

run "service_bindings_can_wait_for_their_targets" {
  command = plan

  variables {
    enable_service_bindings = false
  }

  assert {
    condition     = length(jsondecode(output.wrangler_config_json).services) == 0
    error_message = "With service bindings off, the config must not bind to Workers that may not exist yet."
  }
}
