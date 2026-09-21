data "aws_caller_identity" "current" {}

locals {
  suffix = "${var.project}-${var.env}-${data.aws_caller_identity.current.account_id}"

  buckets = {
    artifacts = {
      name        = "${local.suffix}-artifacts"
      versioning  = true
      # big tarballs, worth moving to cold storage before deleting
      archive     = true
      retain_days = var.artifact_retention_days
    }
    frontend = {
      name        = "${local.suffix}-frontend"
      versioning  = true
      # small files: IA bills a 128 KB minimum per object, so no transitions
      archive     = false
      retain_days = 30
    }
    app = {
      name        = "${local.suffix}-app"
      versioning  = false
      archive     = false
      retain_days = null
    }
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets

  bucket = each.value.name

  tags = { Name = each.value.name }
}

# No public access anywhere. The frontend is reached through CloudFront, not directly.
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.buckets[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs off: the bucket owner owns every object, so only bucket policies and IAM matter.
resource "aws_s3_bucket_ownership_controls" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = { for k, v in local.buckets : k => v if v.versioning }

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Failed multipart uploads are invisible in the console but still billed. Clean them up everywhere.
resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  for_each = local.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = each.value.versioning ? [1] : []

    content {
      id     = "expire-old-versions"
      status = "Enabled"

      filter {}

      dynamic "noncurrent_version_transition" {
        for_each = each.value.archive ? [30, 60] : []

        content {
          noncurrent_days = noncurrent_version_transition.value
          storage_class   = noncurrent_version_transition.value == 30 ? "STANDARD_IA" : "GLACIER"
        }
      }

      noncurrent_version_expiration {
        noncurrent_days = each.value.retain_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.buckets]
}

