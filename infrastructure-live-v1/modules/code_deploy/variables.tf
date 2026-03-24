variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "deployment_group_name" {
  type = string
  default = "backend-deployment-group"
}

variable "codedeploy_name" {
  type = string
  default = "backend-app"
}