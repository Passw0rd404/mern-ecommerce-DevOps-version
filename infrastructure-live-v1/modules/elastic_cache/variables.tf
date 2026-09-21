variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "One private subnet per AZ. One shard is created per subnet."
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "Security group of the app instances allowed to connect"
  type        = string
}

variable "elasticache_node_type" {
  description = "Node instance type. Burstable t4g is fine for dev; use m7g or r7g for real production load."
  type        = string
  default     = "cache.t4g.micro"
}

variable "engine_version" {
  description = "Valkey version. The parameter group follows the major version."
  type        = string
  default     = "8.2"
}

variable "min_replicas" {
  description = "Initial and minimum replicas per shard (the autoscaling floor), 1 to 3"
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 1 && var.min_replicas <= 3
    error_message = "min_replicas must be between 1 and 3."
  }
}

variable "max_replicas" {
  description = "Most replicas per shard autoscaling may add. Worst case node count is one shard per AZ x (1 + max_replicas)."
  type        = number
  default     = 3
}

variable "replica_cpu_target" {
  description = "Replica engine CPU percent the autoscaler aims for (AWS accepts 35 to 70)"
  type        = number
  default     = 60

  validation {
    condition     = var.replica_cpu_target >= 35 && var.replica_cpu_target <= 70
    error_message = "replica_cpu_target must be between 35 and 70."
  }
}

variable "snapshot_retention_days" {
  description = "Days to keep automatic snapshots. 0 disables backups."
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily backup window (UTC). Must not overlap the maintenance window."
  type        = string
  default     = "22:00-23:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:01:00-sun:02:00"
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for encryption at rest. Null uses the AWS-owned key."
  type        = string
  default     = null
}
