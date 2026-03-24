# CloudFront Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "Main CloudFront distribution"

  # Origin 1: S3 Frontend Bucket
  origin {
    origin_id                = "frontend-s3"
    domain_name              = var.frontend_bucket_regional_domain  # from s3 output
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Origin 2: NLB
  origin {
    origin_id   = "backend-nlb"
    domain_name = var.nlb_dns_name  # from NLB output

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # NLB is inside VPC, no need for HTTPS internally
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Behavior 1: /api/* → NLB
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "backend-nlb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress         = true

    # disable caching for API calls
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept", "Origin"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Behavior 2: /* → S3
  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600   # cache for 1 hour
    max_ttl     = 86400  # max 24 hours
  }

  # SPA fallback
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true  # using CloudFront default domain since no custom domain
  }

  tags = {
    Name = "main-distribution"
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id  # passed from s3 module output

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${var.frontend_bucket_arn}/*"  # passed from s3 module output
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}
