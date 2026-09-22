data "aws_region" "current" {}

data "aws_ami" "app" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Project"
    values = [var.ami_project_tag]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id        = coalesce(var.ami_id, one(data.aws_ami.app[*].id))
  use_tls       = var.certificate_arn != null
  listener_port = local.use_tls ? 443 : 80
}

# Security groups
resource "aws_security_group" "nlb" {
  name        = "${var.name}-nlb-sg"
  description = "NLB in front of the backend"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-nlb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Backend instances"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-app-sg" }
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_app" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "Traffic and health checks to the app instances"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_nlb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the NLB only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.nlb.id
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS: Stripe, S3, Secrets Manager, Systems Manager, CodeDeploy, Grafana"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_valkey" {
  security_group_id = aws_security_group.app.id
  description       = "Valkey inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 6379
  to_port           = 6379
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "app_atlas" {
  security_group_id = aws_security_group.app.id
  description       = "MongoDB Atlas PrivateLink (high port range) inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 1024
  to_port           = 65535
  cidr_ipv4         = var.vpc_cidr
}

# Launch template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.name}-"
  image_id               = local.ami_id
  instance_type          = var.instance_type
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.app.id]

  # SECRET_NAME is written here so the AMI stays environment-neutral
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    echo "SECRET_NAME=${var.secret_name}" >> /etc/environment
  EOT
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = var.name }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = var.name }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# One Auto Scaling group per AZ
resource "aws_autoscaling_group" "app" {
  for_each = var.private_subnet_ids_by_az

  name                = "${var.name}-${each.key}"
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = [each.value]

  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period
  target_group_arns         = [aws_lb_target_group.app.arn]

  # The first instances have no app until CodeDeploy delivers one,
  # so do not make terraform apply wait for them to be healthy.
  wait_for_capacity_timeout = "0"

  enabled_metrics = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = var.health_check_grace_period
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${each.key}"
    propagate_at_launch = true
  }

  lifecycle {
    # the scaling policy owns the desired count after creation
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu" {
  for_each = aws_autoscaling_group.app

  name                      = "${var.name}-cpu-${each.key}"
  autoscaling_group_name    = each.value.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = var.health_check_grace_period

  target_tracking_configuration {
    target_value = var.cpu_target

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
