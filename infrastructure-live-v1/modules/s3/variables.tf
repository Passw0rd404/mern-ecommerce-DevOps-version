variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "env" {
    type = string
    default = "prod"
}

# Locals
locals {
  buckets = {
    artifacts = {
      name       = "${var.env}-artifacts"
      versioning = true         # keep old deployment versions
    }
    frontend = {
      name       = "${var.env}-frontend"
      versioning = false
    }
    app = {
      name       = "${var.env}-app"
      versioning = false
    }
  }
}