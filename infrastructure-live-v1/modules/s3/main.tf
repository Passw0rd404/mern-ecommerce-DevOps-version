resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets
  bucket   = each.value.name

  tags = {
    Name = each.value.name
  }
}

# Block all public access for all buckets
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.buckets[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = { for k, v in local.buckets : k => v if v.versioning }

  bucket = aws_s3_bucket.buckets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.buckets["artifacts"].id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    # move non-current versions to cheaper storage after 30 days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # move them to glacier after 60 days
    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}
