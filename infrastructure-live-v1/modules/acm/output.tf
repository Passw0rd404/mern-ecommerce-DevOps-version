output "certificate_arn" {
  description = "Certificate ARN, available only once the certificate is issued"
  value       = aws_acm_certificate_validation.site.certificate_arn
}

output "pending_certificate_arn" {
  description = "Certificate ARN, available immediately (before validation finishes)"
  value       = aws_acm_certificate.site.arn
}
