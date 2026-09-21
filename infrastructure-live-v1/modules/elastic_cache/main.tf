locals {
  # default.valkey8.cluster.on, default.valkey9.cluster.on, ...
  parameter_group = "default.valkey${split(".", var.engine_version)[0]}.cluster.on"
}

resource "random_password" "auth" {
  length  = 32
  special = false
}

resource "aws_elasticache_subnet_group" "main" {
  name        = "valkey-subnet-group"
  description = "Private subnets for Valkey"
  subnet_ids  = var.private_subnet_ids
}

resource "aws_security_group" "valkey" {
  name        = "valkey-sg"
  description = "Valkey access from the app instances only"
  vpc_id      = var.vpc_id

  tags = { Name = "valkey-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  security_group_id            = aws_security_group.valkey.id
  referenced_security_group_id = var.ec2_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  description                  = "Valkey from the app instances"
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "app-valkey"
  description          = "Valkey, cluster mode enabled, one shard per AZ"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.elasticache_node_type
  port                 = 6379
  parameter_group_name = local.parameter_group

  num_node_groups         = length(var.private_subnet_ids)
  replicas_per_node_group = var.min_replicas

  automatic_failover_enabled = true
  multi_az_enabled           = length(var.private_subnet_ids) > 1
  auto_minor_version_upgrade = true

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.valkey.id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  auth_token                 = random_password.auth.result

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  apply_immediately = true

  tags = { Name = "app-valkey" }

  lifecycle {
    # Application Auto Scaling owns the replica count after creation
    ignore_changes = [replicas_per_node_group]
  }
}

resource "aws_appautoscaling_target" "replicas" {
  service_namespace  = "elasticache"
  scalable_dimension = "elasticache:replication-group:Replicas"
  resource_id        = "replication-group/${aws_elasticache_replication_group.main.replication_group_id}"
  min_capacity       = var.min_replicas
  max_capacity       = var.max_replicas

  lifecycle {
    precondition {
      condition     = var.max_replicas >= var.min_replicas
      error_message = "max_replicas must be greater than or equal to min_replicas."
    }
  }
}

resource "aws_appautoscaling_policy" "replicas_cpu" {
  name               = "valkey-replicas-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.replicas.service_namespace
  scalable_dimension = aws_appautoscaling_target.replicas.scalable_dimension
  resource_id        = aws_appautoscaling_target.replicas.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = var.replica_cpu_target
    scale_out_cooldown = 300
    scale_in_cooldown  = 900

    predefined_metric_specification {
      predefined_metric_type = "ElastiCacheReplicaEngineCPUUtilization"
    }
  }
}
