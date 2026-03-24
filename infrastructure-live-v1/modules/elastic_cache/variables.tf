variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "redis_auth_token" {
  description = "Auth token for ElastiCache Valkey"
  type        = string
  sensitive   = true
}

variable "elasticache_node_type" {
  description = "ElastiCache node instance type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ec2_sg_id" {
  type = string
}