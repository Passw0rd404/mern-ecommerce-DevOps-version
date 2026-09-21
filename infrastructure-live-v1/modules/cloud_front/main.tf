data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

# One OAC serves both S3 origins
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "s3-oac"
  description                       = "Lets CloudFront read the private frontend and app buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Holds one key, "version". CI updates it on every release or rollback.
resource "aws_cloudfront_key_value_store" "release" {
  name    = "frontend-release"
  comment = "Active frontend version, written by CI"
}

resource "aws_cloudfront_function" "router" {
  name                         = "frontend-router"
  runtime                      = "cloudfront-js-2.0"
  comment                      = "Serves the active frontend version and handles SPA routes"
  publish                      = true
  code                         = file("${path.module}/router.js")
  key_value_store_associations = [aws_cloudfront_key_value_store.release.arn]
}

# Private path from CloudFront to the internal NLB
resource "aws_cloudfront_vpc_origin" "backend" {
  vpc_origin_endpoint_config {
    name                   = "backend-nlb"
    arn                    = var.nlb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

# CloudFront creates this security group in your VPC for its VPC origins
data "aws_security_group" "vpc_origin_service" {
  name       = "CloudFront-VPCOrigins-Service-SG"
  vpc_id     = var.vpc_id
  depends_on = [aws_cloudfront_vpc_origin.backend]
}

resource "aws_vpc_security_group_ingress_rule" "nlb_from_cloudfront" {
  security_group_id            = var.nlb_security_group_id
  referenced_security_group_id = data.aws_security_group.vpc_origin_service.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "CloudFront VPC origin to NLB"
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  comment         = "Main CloudFront distribution"
  aliases         = var.aliases

  origin {
    origin_id                = "frontend-s3"
    domain_name              = var.frontend_bucket_regional_domain
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    origin_id                = "app-s3"
    domain_name              = var.app_bucket_regional_domain
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    origin_id   = "backend-nlb"
    domain_name = var.nlb_dns_name

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.backend.id
    }
  }

  # API: never cached, everything forwarded (the JWTs travel in cookies)
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "backend-nlb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  # Product images uploaded by the backend (s3.js returns CLOUDFRONT_URL/products/<uuid>.jpg)
  ordered_cache_behavior {
    path_pattern               = "/products/*"
    target_origin_id           = "app-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  # Everything else is the frontend, rewritten by the function
  default_cache_behavior {
    target_origin_id           = "frontend-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.router.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? null : "TLSv1.2_2021"
  }

  lifecycle {
    precondition {
      condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
      error_message = "acm_certificate_arn is required when aliases is set."
    }
  }

  tags = { Name = "main-distribution" }
}

# One policy per bucket: S3 allows only one, so everything for a bucket lives here.
data "aws_iam_policy_document" "frontend" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${var.frontend_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [var.frontend_bucket_arn, "${var.frontend_bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "AllowCloudFrontOACReadImages"
    actions   = ["s3:GetObject"]
    resources = ["${var.app_bucket_arn}/products/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [var.app_bucket_arn, "${var.app_bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Writes and deletes are only possible from inside the VPC, through its S3 endpoint
  dynamic "statement" {
    for_each = var.app_write_vpce_id == null ? [] : [1]

    content {
      sid       = "DenyWritesOutsideVpcEndpoint"
      effect    = "Deny"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = ["${var.app_bucket_arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        variable = "aws:SourceVpce"
        values   = [var.app_write_vpce_id]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id
  policy = data.aws_iam_policy_document.frontend.json
}

resource "aws_s3_bucket_policy" "app" {
  bucket = var.app_bucket_id
  policy = data.aws_iam_policy_document.app.json
}
