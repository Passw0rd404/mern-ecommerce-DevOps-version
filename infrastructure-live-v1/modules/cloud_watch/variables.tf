variable "grafana_external_id" {
  description = "External ID from the 'Create new account' page in Grafana Cloud (Cloud Provider > AWS)"
  type        = string
}

variable "grafana_aws_account_id" {
  description = "Grafana Labs' AWS account ID for the CloudWatch integration — verify against the 'Create new account' page"
  type        = string
  default     = "008923505280"
}

variable "iam_role_name" {
  type    = string
  default = "GrafanaCloudWatchIntegration"
}
