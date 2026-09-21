resource "aws_acm_certificate" "site" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Blocks until you add the validation CNAME in Cloudflare and ACM issues the certificate.
resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn

  timeouts {
    create = "30m"
  }
}
