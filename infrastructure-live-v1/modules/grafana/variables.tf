variable "stack_slug" {
  description = "Your Grafana Cloud stack name"
  type        = string
}

variable "cloudwatch_role_arn" {
  description = "role_arn output from the cloud_watch module"
  type        = string
}

variable "aws_regions" {
  type    = list(string)
  default = ["eu-central-1"]
}
