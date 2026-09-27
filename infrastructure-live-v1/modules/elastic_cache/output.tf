output "redis_host" {
  description = "Configuration endpoint (cluster mode enabled)"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "redis_port" {
  description = "Valkey port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_auth_token" {
  description = "Auth token, generated here and stored in the app secret"
  value       = random_password.auth.result
  sensitive   = true
}

output "redis_security_group_id" {
  value = aws_security_group.valkey.id
}

output "configuration_endpoint_address" {
  value = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "auth_token" {
  value     = random_password.auth.result
  sensitive = true
}
