variable "vpc_cidr" {
  description = "CIDR block for the VPC (a /16 is assumed by the automatic subnet calculation)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "pub_cidrs" {
  description = "Optional. One public subnet CIDR per AZ. Leave empty to calculate them automatically."
  type        = list(string)
  default     = []
}

variable "prv_cidrs" {
  description = "Optional. One private subnet CIDR per AZ. Leave empty to calculate them automatically."
  type        = list(string)
  default     = []
}

variable "interface_endpoints" {
  description = "Extra interface (PrivateLink) endpoints keyed by name, for example MongoDB Atlas or Grafana Cloud."
  type = map(object({
    service_name        = string
    private_dns_enabled = optional(bool, false)
    from_port           = optional(number, 443)
    to_port             = optional(number, 443)
  }))
  default = {}
}
