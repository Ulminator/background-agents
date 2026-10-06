output "worker_name" {
  description = "The name of the deployed worker"
  value       = cloudflare_worker.this.name
}

output "worker_id" {
  description = "The ID of the worker"
  value       = cloudflare_worker.this.id
}

output "worker_url" {
  description = "The workers.dev URL for the worker: https://<worker_name>.<worker_subdomain>.workers.dev"
  value       = "https://${cloudflare_worker.this.name}.${var.worker_subdomain}.workers.dev"
}

output "custom_domain" {
  description = "The custom domain for the worker (if configured)"
  value       = var.custom_domain != null ? cloudflare_workers_custom_domain.this[0].hostname : null
}

output "plain_text_binding_names" {
  description = "Names of configured plain-text bindings."
  value       = keys(var.plain_text_bindings)
}

output "plain_text_bindings" {
  description = "Configured plain-text bindings as a name => value map, so a configuration test can assert the value a binding actually carries."
  value       = { for name, binding in var.plain_text_bindings : name => binding.value }
}

output "secret_binding_names" {
  description = "Names of configured secret bindings; secret values are not exposed."
  value       = nonsensitive(keys(var.secrets))
}

output "wrangler_config_json" {
  description = "Wrangler configuration for this Worker as JSON, without secrets or Durable Object migrations. The deploy workflow writes it to wrangler.json."
  value       = jsonencode(local.wrangler_config)
}

output "secrets" {
  description = "Secret bindings as a name => value map, uploaded with each version through `wrangler deploy --secrets-file`."
  value       = { for name, binding in var.secrets : name => binding.value }
  sensitive   = true
}
