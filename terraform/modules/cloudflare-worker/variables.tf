variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID (required for routes and custom domains)"
  type        = string
  default     = null
}

variable "worker_name" {
  description = "Name of the worker"
  type        = string
}

variable "worker_subdomain" {
  description = "Cloudflare account workers.dev subdomain label, e.g. 'myaccount' (without '.workers.dev'). worker_url resolves to <worker_name>.<worker_subdomain>.workers.dev."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", var.worker_subdomain))
    error_message = "worker_subdomain must be a single workers.dev subdomain label (e.g. 'myaccount'): lowercase alphanumeric and hyphens only, no dots — do not include '.workers.dev'."
  }
}

variable "bundle_path" {
  description = "Repository-relative path of the built bundle the deploy workflow uploads, e.g. packages/control-plane/dist/index.js."
  type        = string
}

variable "kv_namespaces" {
  description = "Map of KV namespace bindings keyed by binding name"
  type = map(object({
    namespace_id = string
  }))
  default = {}
}

variable "service_bindings" {
  description = "Map of service bindings keyed by binding name for worker-to-worker communication"
  type = map(object({
    service_name = string
  }))
  default = {}
}

variable "d1_databases" {
  description = "Map of D1 database bindings keyed by binding name"
  type = map(object({
    database_id = string
  }))
  default = {}
}

variable "r2_buckets" {
  description = "Map of R2 bucket bindings keyed by binding name"
  type = map(object({
    bucket_name = string
  }))
  default = {}
}

variable "queue_bindings" {
  description = "Map of Queue producer bindings keyed by binding name"
  type = map(object({
    queue_name = string
  }))
  default = {}
}

variable "queue_consumers" {
  description = "Queues this Worker consumes, keyed by queue name. Timeouts and delays are seconds, the unit Wrangler takes."
  type = map(object({
    dead_letter_queue         = optional(string)
    max_batch_size            = optional(number)
    max_batch_timeout_seconds = optional(number)
    max_concurrency           = optional(number)
    max_retries               = optional(number)
    retry_delay_seconds       = optional(number)
  }))
  default = {}
}

variable "plain_text_bindings" {
  description = "Map of plain text environment variable bindings keyed by binding name"
  type = map(object({
    value = string
  }))
  default = {}
}

variable "secrets" {
  description = "Map of secret bindings keyed by binding name"
  type = map(object({
    value = string
  }))
  default   = {}
  sensitive = true
}

variable "durable_objects" {
  description = "Map of Durable Object bindings keyed by binding name"
  type = map(object({
    class_name = string
  }))
  default = {}
}

variable "enable_service_bindings" {
  description = "Enable service bindings. Set false if target workers don't exist yet."
  type        = bool
  default     = true
}

variable "cron_triggers" {
  description = "List of cron expressions for the worker's scheduled() handler"
  type        = list(string)
  default     = []
}

variable "compatibility_date" {
  description = "Compatibility date for the worker"
  type        = string
  default     = "2024-01-01"
}

variable "compatibility_flags" {
  description = "Compatibility flags for the worker (e.g., ['nodejs_compat'])"
  type        = list(string)
  default     = []
}

variable "custom_domain" {
  description = "Custom domain hostname for the worker"
  type        = string
  default     = null
}

variable "route_pattern" {
  description = "Route pattern for zone-based routing (e.g., 'example.com/*')"
  type        = string
  default     = null
}
