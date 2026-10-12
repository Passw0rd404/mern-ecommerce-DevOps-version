variable "vpc_id" {
  description = "VPC the private zone is attached to"
  type        = string
}

variable "url" {
  description = "URL whose hostname gets a private zone, e.g. https://host.example.net/otlp"
  type        = string
}

variable "alias_dns_name" {
  description = "DNS name of the VPC endpoint the hostname should resolve to"
  type        = string
}

variable "alias_zone_id" {
  description = "Hosted zone ID of the VPC endpoint's DNS entry"
  type        = string
}
