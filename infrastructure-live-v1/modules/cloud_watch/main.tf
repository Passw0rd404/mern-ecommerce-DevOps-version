data "aws_iam_policy_document" "trust_grafana" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.grafana_aws_account_id}:root"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.grafana_external_id]
    }
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = var.iam_role_name
  description        = "Role Grafana Cloud assumes to read CloudWatch metrics"
  assume_role_policy = data.aws_iam_policy_document.trust_grafana.json
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "${var.iam_role_name}Policy"
  role = aws_iam_role.grafana_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "tag:GetResources",
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "autoscaling:DescribeAutoScalingGroups",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticache:DescribeCacheClusters",
        "elasticache:DescribeReplicationGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNatGateways",
        "ec2:DescribeVpcEndpoints"
      ]
      Resource = "*"
    }]
  })
}

resource "time_sleep" "wait_iam_propagation" {
  depends_on      = [aws_iam_role.grafana_cloudwatch, aws_iam_role_policy.grafana_cloudwatch]
  create_duration = "10s"
}
