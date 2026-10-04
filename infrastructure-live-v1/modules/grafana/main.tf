data "grafana_cloud_stack" "this" {
  slug = var.stack_slug
}

resource "grafana_cloud_provider_aws_account" "this" {
  stack_id = data.grafana_cloud_stack.this.id
  role_arn = var.cloudwatch_role_arn
  regions  = concat(var.aws_regions, ["us-east-1"]) # us-east-1 added: CloudFront only publishes metrics there
}

resource "grafana_cloud_provider_aws_cloudwatch_scrape_job" "core" {
  stack_id                = data.grafana_cloud_stack.this.id
  name                    = "mern-dev-scrape"
  aws_account_resource_id = grafana_cloud_provider_aws_account.this.resource_id

  service {
    name = "AWS/NetworkELB"
    metric {
      name       = "ActiveFlowCount"
      statistics = ["Average"]
    }
    metric {
      name       = "HealthyHostCount"
      statistics = ["Minimum"]
    }
    scrape_interval_seconds = 300
  }

  service {
    name = "AWS/ElastiCache"
    metric {
      name       = "CPUUtilization"
      statistics = ["Average"]
    }
    metric {
      name       = "CurrConnections"
      statistics = ["Average"]
    }
    scrape_interval_seconds = 300
  }

  service {
    name = "AWS/EC2"
    metric {
      name       = "CPUUtilization"
      statistics = ["Average"]
    }
    metric {
      name       = "StatusCheckFailed"
      statistics = ["Maximum"]
    }
    scrape_interval_seconds = 300
  }

  service {
    name = "AWS/AutoScaling"
    metric {
      name       = "GroupInServiceInstances"
      statistics = ["Average"]
    }
    metric {
      name       = "GroupDesiredCapacity"
      statistics = ["Average"]
    }
    scrape_interval_seconds = 300
  }

  service {
    name = "AWS/NATGateway"
    metric {
      name       = "BytesOutToDestination"
      statistics = ["Sum"]
    }
    metric {
      name       = "ErrorPortAllocation"
      statistics = ["Sum"]
    }
    scrape_interval_seconds = 300
  }

  service {
    name = "AWS/S3"
    metric {
      name       = "BucketSizeBytes"
      statistics = ["Average"]
    }
    metric {
      name       = "NumberOfObjects"
      statistics = ["Average"]
    }
    scrape_interval_seconds = 3600
  }
}

resource "grafana_cloud_provider_aws_cloudwatch_scrape_job" "cloudfront" {
  stack_id                = data.grafana_cloud_stack.this.id
  name                    = "mern-dev-cloudfront-scrape"
  aws_account_resource_id = grafana_cloud_provider_aws_account.this.resource_id

  service {
    name = "AWS/CloudFront"
    metric {
      name       = "Requests"
      statistics = ["Sum"]
    }
    metric {
      name       = "5xxErrorRate"
      statistics = ["Average"]
    }
    metric {
      name       = "CacheHitRate"
      statistics = ["Average"]
    }
    scrape_interval_seconds = 300
  }
}
