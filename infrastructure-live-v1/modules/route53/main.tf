locals {
  host = regex("^https?://([^/]+)", var.url)[0]
}

# Scoped to the exact hostname, so no other names under the same domain are shadowed
resource "aws_route53_zone" "this" {
  name = local.host

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "this" {
  zone_id = aws_route53_zone.this.zone_id
  name    = local.host
  type    = "A"

  alias {
    name                   = var.alias_dns_name
    zone_id                = var.alias_zone_id
    evaluate_target_health = true
  }
}
