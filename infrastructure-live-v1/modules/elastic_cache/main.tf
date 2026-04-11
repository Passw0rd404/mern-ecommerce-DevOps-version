resource "aws_elasticache_subnet_group" "main" {
  name        = "elasticache-subnet-group"
  description = "Private subnets for ElastiCache"
  subnet_ids  = var.private_subnet_ids
}

# Security group for ElastiCache
resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-sg"
  description = "Allow Redis access from ASG EC2 only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Valkey from EC2 ASG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elasticache-sg"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "app-valkey"
  description          = "Valkey single node"
  engine               = "valkey"
  engine_version       = "8.0"
  node_type            = var.elasticache_node_type
  port                 = 6379

  # single node — no replicas
  num_cache_clusters         = 1
  automatic_failover_enabled = false   # can't be true with single node

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache_sg.id]

  auth_token                 = var.redis_auth_token
  transit_encryption_enabled = true

  apply_immediately = true

  tags = {
    Name = "app-valkey"
  }
}