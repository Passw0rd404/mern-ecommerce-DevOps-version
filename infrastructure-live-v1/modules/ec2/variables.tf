variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "backend"
}

variable "vpc_id" {
  description = "VPC id (from the vpc module)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to limit outbound rules to Valkey and Atlas"
  type        = string
}

variable "private_subnet_ids_by_az" {
  description = "AZ name to private subnet id. One Auto Scaling group is created per entry."
  type        = map(string)
}

variable "ami_id" {
  description = "AMI to launch. Null means the newest AMI in this account tagged Project=<ami_project_tag> (built by Packer)."
  type        = string
  default     = null
}

variable "ami_project_tag" {
  description = "Value of the Project tag that Packer puts on the AMI"
  type        = string
  default     = "mern"
}

variable "instance_type" {
  description = "Instance type. Must be x86_64 because the AMI is x86_64."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "app_port" {
  description = "Port the Node app listens on"
  type        = number
  default     = 5000
}

variable "min_size" {
  description = "Minimum instances per AZ"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum instances per AZ"
  type        = number
  default     = 3
}

variable "cpu_target" {
  description = "Average CPU percent each Auto Scaling group aims for"
  type        = number
  default     = 60
}

variable "health_check_grace_period" {
  description = "Seconds before health checks count after launch. Must cover boot plus the CodeDeploy deployment."
  type        = number
  default     = 300
}

variable "health_check_path" {
  description = "HTTP path the NLB checks on each instance"
  type        = string
  default     = "/api/health"
}

variable "certificate_arn" {
  description = "Regional ACM certificate (same region as the NLB) for a TLS listener on 443. Null means a plain TCP listener on 80, for dev only."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "TLS security policy for the listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "deletion_protection" {
  description = "Block deleting the NLB. Set true in prod; keep false where CI destroys the environment."
  type        = bool
  default     = false
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret the app reads at deploy time"
  type        = string
}

variable "secret_name" {
  description = "Name of that secret. Written to /etc/environment as SECRET_NAME at first boot."
  type        = string
}

variable "uploads_bucket_arn" {
  description = "ARN of the product images bucket"
  type        = string
}

variable "codedeploy_bucket_name" {
  description = "S3 bucket where CI stores the CodeDeploy bundles"
  type        = string
}
