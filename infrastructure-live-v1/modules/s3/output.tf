output "artifacts_bucket_name" {
  description = "Artifacts bucket name"
  value       = aws_s3_bucket.buckets["artifacts"].id
}

output "frontend_bucket_name" {
  description = "Frontend bucket name"
  value       = aws_s3_bucket.buckets["frontend"].id
}

output "app_bucket_name" {
  description = "app bucket name"
  value       = aws_s3_bucket.buckets["app"].id
}

output "app_bucket_arn" {
  description = "app bucket ARN for EC2 IAM policy"
  value       = aws_s3_bucket.buckets["app"].arn
}

output "frontend_bucket_regional_domain" {
  description = "Frontend bucket regional domain for CloudFront origin"
  value       = aws_s3_bucket.buckets["frontend"].bucket_regional_domain_name
}

output "frontend_bucket_id" {
  description = "Frontend bucket id"
  value       = aws_s3_bucket.buckets["frontend"].id
}

output "frontend_bucket_arn" {
  description = "Frontend bucket arn"
  value       = aws_s3_bucket.buckets["frontend"].arn
}