variable "deployment_group_name" {
  type    = string
  default = "backend-deployment-group"
}

variable "codedeploy_name" {
  type    = string
  default = "backend-app"
}

variable "autoscaling_group_name" {
  description = "Name of the ASG to deploy to (output of the ec2 module)"
  type        = string
}

variable "target_group_name" {
  description = "Name of the load balancer target group (output of the ec2 module)"
  type        = string
}
