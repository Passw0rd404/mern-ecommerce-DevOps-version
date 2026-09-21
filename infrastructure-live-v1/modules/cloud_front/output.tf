output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "distribution_domain_name" {
  description = "Target for the DNS record of your custom domain"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Needed for a Route 53 alias record"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "kvs_arn" {
  description = "Key Value Store the release workflows write to (GitHub secret CLOUDFRONT_KVS_ARN)"
  value       = aws_cloudfront_key_value_store.release.arn
}
