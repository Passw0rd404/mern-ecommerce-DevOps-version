variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "atlas_public_key" {
  description = "MongoDB Atlas API public key"
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "MongoDB Atlas API private key"
  type        = string
  sensitive   = true
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Atlas project"
  type        = string
  default     = "my-project"
}

variable "cluster_name" {
  description = "Name of the Atlas cluster"
  type        = string
  default     = "my-free-cluster"
}

variable "cloud_provider" {
  description = "Backing cloud provider for M0 (AWS, GCP, or AZURE)"
  type        = string
  default     = "AWS"
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "allowed_cidr" {
  description = "CIDR block allowed to connect (use 0.0.0.0/0 to allow all, restrict in prod)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_endpoint_id" {
  description = "The VPC endpoint ID from your vpc_endpoints module (aws_vpc_endpoint.mongodb_atlas.id)"
  type        = string
}