resource "aws_lb" "app" {
  name               = "${var.name}-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = values(var.private_subnet_ids_by_az)
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.deletion_protection

  tags = { Name = "${var.name}-nlb" }
}

resource "aws_lb_target_group" "app" {
  name_prefix          = "app-"
  port                 = var.app_port
  protocol             = "TCP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    protocol            = "HTTP"
    path                = var.health_check_path
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = local.listener_port
  protocol          = local.use_tls ? "TLS" : "TCP"
  ssl_policy        = local.use_tls ? var.ssl_policy : null
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
