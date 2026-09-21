variable "frontend_bucket_regional_domain" {
  type = string
}

variable "frontend_bucket_id" {
  type = string
}

variable "frontend_bucket_arn" {
  type = string
}

variable "app_bucket_regional_domain" {
  type = string
}

variable "app_bucket_id" {
  type = string
}

variable "app_bucket_arn" {
  type = string
}

variable "app_write_vpce_id" {
  description = "S3 gateway endpoint id. When set, only that endpoint may write or delete objects in the app bucket."
  type        = string
  default     = null
}

variable "vpc_id" {
  type = string
}

variable "nlb_arn" {
  description = "ARN of the internal NLB serving /api/*"
  type        = string
}

variable "nlb_dns_name" {
  type = string
}

variable "nlb_security_group_id" {
  description = "Security group attached to the NLB"
  type        = string
}

variable "aliases" {
  description = "Custom domain names for the distribution. Empty uses the *.cloudfront.net name."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "Issued ACM certificate in us-east-1. Required when aliases is set."
  type        = string
  default     = null
}
