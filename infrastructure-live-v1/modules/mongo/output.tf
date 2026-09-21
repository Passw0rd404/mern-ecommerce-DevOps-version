output "privatelink_service_name" {
  description = "Atlas PrivateLink service name; the vpc module creates the interface endpoint from it"
  value       = mongodbatlas_privatelink_endpoint.this.endpoint_service_name
}

output "project_id" {
  description = "MongoDB Atlas project ID"
  value       = mongodbatlas_project.this.id
}

output "cluster_name" {
  description = "MongoDB Atlas cluster name"
  value       = mongodbatlas_advanced_cluster.this.name
}

output "connection_uri" {
  description = "Private-endpoint SRV URI with credentials and database name"
  value       = "mongodb+srv://${var.db_username}:${random_password.db.result}@${replace(local.private_srv[0], "mongodb+srv://", "")}/${var.database_name}?retryWrites=true&w=majority"
  sensitive   = true
}

output "state" {
  description = "Current state of the cluster"
  value       = mongodbatlas_advanced_cluster.this.state_name
}
