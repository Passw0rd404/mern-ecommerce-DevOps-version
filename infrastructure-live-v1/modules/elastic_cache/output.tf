output "redis_host" {
  description = "ElastiCache Valkey endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "ElastiCache Valkey port"
  value       = aws_elasticache_replication_group.main.port
}