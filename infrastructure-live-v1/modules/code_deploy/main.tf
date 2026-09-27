# IAM role that lets CodeDeploy act on your behalf
resource "aws_iam_role" "codedeploy" {
  name = "codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# CodeDeploy application
resource "aws_codedeploy_app" "backend" {
  name             = var.codedeploy_name
  compute_platform = "Server" # EC2/on-premises
}

# Deployment group
resource "aws_codedeploy_deployment_group" "backend" {
  app_name              = aws_codedeploy_app.backend.name
  deployment_group_name = var.deployment_group_name
  service_role_arn      = aws_iam_role.codedeploy.arn

  # the ASG and target group come from the ec2 module through variables
  autoscaling_groups = var.autoscaling_group_names

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info {
      name = var.target_group_name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # one instance at a time keeps capacity as the fleet grows
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  depends_on = [aws_iam_role_policy_attachment.codedeploy]
}
