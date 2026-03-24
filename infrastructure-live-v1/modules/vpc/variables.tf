# Variables
variable "vpc" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "pub_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24"]
}

variable "prv_cidrs" {
  type    = list(string)
  default = ["10.0.2.0/24"]
}

variable "region" {
    description = "AWS region"
    type = string
    default = "eu-north-1"
}

variable "az_num" {
  description = "the number of azs in the region I want to provision"
  type    = number
  default = 1
}

#Locals
# Data source to get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_num)
}

# to get my ip to give it access to port 22
data "http" "my_ip" {
    url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = "${chomp(data.http.my_ip.response_body)}/32"
}