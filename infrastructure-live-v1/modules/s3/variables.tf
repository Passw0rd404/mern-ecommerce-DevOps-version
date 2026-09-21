variable "env" {
  description = "Environment name, used in bucket names (dev, prod, ...)"
  type        = string
}

variable "project" {
  description = "Project name, used in bucket names"
  type        = string
  default     = "mern"
}

variable "artifact_retention_days" {
  description = "How long to keep old (non-current) deployment bundles before deleting them"
  type        = number
  default     = 180
}

variable "force_destroy" {
     description = "Let terraform destroy delete non-empty buckets (dev only)"
     type        = bool
     default     = false
   }
