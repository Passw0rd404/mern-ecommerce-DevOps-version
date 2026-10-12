output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "host" {
  value = local.host
}
