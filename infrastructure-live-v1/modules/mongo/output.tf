output "mongodb_endpoint_id" {
  value = aws_vpc_endpoint.mongodb_atlas.id
}

output "project_id" {
  description = "MongoDB Atlas project ID"
  value       = mongodbatlas_project.this.id
}

output "cluster_id" {
  description = "MongoDB Atlas cluster ID"
  value       = mongodbatlas_cluster.this.cluster_id
}

output "connection_uri" {
  description = "Standard MongoDB connection URI (with credentials embedded)"
  value       = "mongodb+srv://${var.db_username}:${var.db_password}@${mongodbatlas_cluster.this.connection_strings[0].standard_srv}"
  sensitive   = true
}

output "connection_uri_srv" {
  description = "SRV connection string without credentials (safer to log)"
  value       = mongodbatlas_cluster.this.connection_strings[0].standard_srv
}

output "state" {
  description = "Current state of the cluster"
  value       = mongodbatlas_cluster.this.state_name
}