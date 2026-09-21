output "certificate_arn" {
  description = "Certificate ARN, available only once the certificate is issued"
  value       = aws_acm_certificate_validation.site.certificate_arn
}
