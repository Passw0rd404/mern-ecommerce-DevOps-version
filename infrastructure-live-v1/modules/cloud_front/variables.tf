variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "frontend_bucket_regional_domain" {
  description = "From S3 module output"
}

variable "nlb_dns_name" {
  description = "From NLB module output"
}

variable "frontend_bucket_arn" {
  description = "From NLB module output"
}

variable "frontend_bucket_id" {
  description = "From NLB module output"
}