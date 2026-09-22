output "app_name" {
  value = aws_codedeploy_app.backend.name
}

output "deployment_group_name" {
  value = aws_codedeploy_deployment_group.backend.deployment_group_name
}

output "configuration_endpoint_address" {
  value = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "auth_token" {
  value     = random_password.auth.result
  sensitive = true
}
