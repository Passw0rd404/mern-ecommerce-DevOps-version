variable "vpc_cidr" {
  description = "CIDR block for the VPC (a /16 is assumed by the automatic subnet calculation)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_num" {
  description = "Number of AZs to use. Each AZ gets one public and one private subnet. An internet-facing ALB needs at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_num >= 1 && var.az_num <= 6
    error_message = "az_num must be between 1 and 6."
  }
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

variable "single_nat_gateway" {
  description = "true = one NAT gateway for all AZs (cheaper, good for dev). false = one NAT per AZ (survives an AZ failure)."
  type        = bool
  default     = false
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
