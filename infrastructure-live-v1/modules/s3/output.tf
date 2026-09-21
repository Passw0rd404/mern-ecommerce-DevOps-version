output "artifacts_bucket_name" {
  description = "Artifacts bucket name"
  value       = aws_s3_bucket.buckets["artifacts"].id
}

output "artifacts_bucket_arn" {
  description = "Artifacts bucket ARN for the EC2 and CodeDeploy IAM policies"
  value       = aws_s3_bucket.buckets["artifacts"].arn
}

output "frontend_bucket_name" {
  description = "Frontend bucket name"
  value       = aws_s3_bucket.buckets["frontend"].id
}

output "frontend_bucket_id" {
  description = "Frontend bucket id"
  value       = aws_s3_bucket.buckets["frontend"].id
}

output "frontend_bucket_arn" {
  description = "Frontend bucket ARN (for the CloudFront OAC bucket policy)"
  value       = aws_s3_bucket.buckets["frontend"].arn
}

output "frontend_bucket_regional_domain" {
  description = "Frontend bucket regional domain for the CloudFront origin"
  value       = aws_s3_bucket.buckets["frontend"].bucket_regional_domain_name
}

output "app_bucket_name" {
  description = "App bucket name"
  value       = aws_s3_bucket.buckets["app"].id
}

output "app_bucket_arn" {
  description = "App bucket ARN for the EC2 IAM policy"
  value       = aws_s3_bucket.buckets["app"].arn
}

output "app_bucket_regional_domain" {
  description = "App bucket regional domain for the CloudFront origin"
  value       = aws_s3_bucket.buckets["app"].bucket_regional_domain_name
}
