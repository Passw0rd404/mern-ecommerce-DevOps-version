data "aws_region" "current" {}

locals {
  app_env_defaults = {
    NODE_ENV = "production"
    PORT     = tostring(var.app_port)
  }
}

resource "random_password" "access_token" {
  length  = 64
  special = false
}

resource "random_password" "refresh_token" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "backend" {
  name                    = var.secret_name
  description             = "Backend environment variables, read by scripts/after-install.sh"
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id

  # Later maps win: app_env can override the defaults but never the credentials below.
  secret_string = jsonencode(merge(
    local.app_env_defaults,
    var.app_env,
    {
      MONGO_URI            = var.mongo_uri
      REDIS_MODE           = "cluster"
      REDIS_HOST           = var.redis_host
      REDIS_PORT           = "6379"
      REDIS_TLS            = "true"
      REDIS_PASSWORD       = var.redis_password
      ACCESS_TOKEN_SECRET  = random_password.access_token.result
      REFRESH_TOKEN_SECRET = random_password.refresh_token.result
      STRIPE_SECRET_KEY    = var.stripe_secret_key
      CLIENT_URL           = var.client_url
      AWS_REGION           = data.aws_region.current.region
      S3_BUCKET_NAME       = var.uploads_bucket_name
      CLOUDFRONT_URL       = var.cloudfront_url
    }
  ))
}
