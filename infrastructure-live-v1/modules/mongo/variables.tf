variable "region" {
  description = "AWS region of the VPC, also where the cluster runs (for example eu-north-1)"
  type        = string
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Atlas project"
  type        = string
  default     = "mern"
}

variable "cluster_name" {
  description = "Name of the Atlas cluster"
  type        = string
  default     = "app"
}

variable "mongo_db_major_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
}

variable "instance_size" {
  description = "Cluster tier and autoscaling floor. PrivateLink needs M10 or larger."
  type        = string
  default     = "M10"
}

variable "max_instance_size" {
  description = "Highest tier compute autoscaling may scale up to"
  type        = string
  default     = "M30"
}

variable "database_name" {
  description = "Database the app uses; the user gets readWrite on it only"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app"
}

variable "termination_protection" {
  description = "Block deleting the cluster. Set true in prod; keep false where CI destroys the environment."
  type        = bool
  default     = false
}

variable "vpc_endpoint_id" {
  description = "ID of the interface endpoint created by the vpc module for Atlas"
  type        = string
}
