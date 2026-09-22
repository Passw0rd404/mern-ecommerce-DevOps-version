variable "secret_name" {
  description = "Secrets Manager name the instances read"
  type        = string
  default     = "ecommerce/dev/backend"
}

variable "recovery_window_in_days" {
  description = "0 deletes immediately, so CI can destroy and recreate the same name. Use 7 to 30 in prod."
  type        = number
  default     = 0
}

variable "mongo_uri" {
  description = "Private-endpoint MongoDB URI (mongo module output)"
  type        = string
  sensitive   = true
}

variable "redis_host" {
  description = "Valkey configuration endpoint"
  type        = string
}

variable "redis_password" {
  description = "Valkey auth token"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
}

variable "client_url" {
  description = "Public URL of the site (used for Stripe redirects)"
  type        = string
}

variable "uploads_bucket_name" {
  description = "Product images bucket name"
  type        = string
}

variable "cloudfront_url" {
  description = "Base URL that serves /products/*, with no trailing slash"
  type        = string
}

variable "app_port" {
  description = "Port the Node app listens on (same value the NLB targets)"
  type        = number
  default     = 5000
}

variable "app_env" {
  description = "Extra non-secret environment variables for the app. They override the defaults, never the generated credentials."
  type        = map(string)
  default     = {}
}
