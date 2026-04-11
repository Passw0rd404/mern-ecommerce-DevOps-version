###############################################################################
# vpc_endpoints.tf
# Three VPC endpoints:
#   1. S3 gateway endpoint         – EC2 → S3 over AWS backbone (free)
#   2. MongoDB Atlas interface endpoint – EC2 → Atlas via PrivateLink
#   3. Grafana Cloud interface endpoint – EC2 → Grafana via PrivateLink
#
# PLACEHOLDERS to replace before applying:
#   var.vpc_id                   – your VPC ID
#   var.subnet_ids               – list of private subnet IDs for interface EPs
#   var.route_table_ids          – route table IDs for S3 gateway EP
#   var.ec2_security_group_id    – SG of the EC2 instance(s)
#   var.mongodb_service_name     – Atlas PrivateLink service name
#                                  (find in Atlas UI: Network Access → Private Endpoint)
#                                  e.g. "com.amazonaws.vpce.us-east-1.vpce-svc-xxxxxxxxx"
#   var.grafana_service_name     – Grafana Cloud PrivateLink service name
#                                  (find in Grafana Cloud portal or ask Grafana support)
#                                  e.g. "com.amazonaws.vpce.us-east-1.vpce-svc-yyyyyyyyy"
###############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

###############################################################################
# Variables
###############################################################################

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC where endpoints will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for interface endpoints (one per AZ recommended)"
  type        = list(string)
}

variable "route_table_ids" {
  description = "Route table IDs to associate with the S3 gateway endpoint"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security group ID of the EC2 instance(s) that will use the endpoints"
  type        = string
}

variable "mongodb_service_name" {
  description = "MongoDB Atlas PrivateLink VPC endpoint service name"
  type        = string
  # Example: "com.amazonaws.vpce.us-east-1.vpce-svc-xxxxxxxxxxxxxxxxx"
}

variable "grafana_service_name" {
  description = "Grafana Cloud PrivateLink VPC endpoint service name"
  type        = string
  # Example: "com.amazonaws.vpce.us-east-1.vpce-svc-yyyyyyyyyyyyyyyyy"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}

###############################################################################
# Provider
###############################################################################

provider "aws" {
  region = var.aws_region
}

###############################################################################
# Data sources
###############################################################################

data "aws_vpc" "this" {
  id = var.vpc_id
}

###############################################################################
# 1. S3 Gateway Endpoint
#
#    - Type: Gateway (free, no ENI, no SG needed)
#    - Traffic never leaves the AWS network
#    - Works by injecting a prefix-list route into the specified route tables
#    - Supports S3 and DynamoDB gateway endpoints only
###############################################################################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "vpce-s3-gateway"
  })
}

###############################################################################
# Security group for interface endpoints (MongoDB Atlas + Grafana Cloud)
#
#    - Allows HTTPS (443) inbound from the EC2 security group only
#    - Egress is unrestricted (endpoints need to reach the service)
###############################################################################

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpce-interface-endpoints-sg"
  description = "Allow HTTPS from EC2 instances to interface VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from EC2 instances"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "vpce-interface-endpoints-sg"
  })
}

###############################################################################
# 2. MongoDB Atlas Interface Endpoint (PrivateLink)
#
#    - Type: Interface (creates ENIs in your subnets)
#    - After Terraform apply you must accept the connection in Atlas:
#        Atlas UI → Network Access → Private Endpoint → Pending
#    - Atlas also requires you to register the VPC endpoint ID in Atlas
#        (see Atlas docs: Set Up a Private Endpoint for a Dedicated Cluster)
###############################################################################

resource "aws_vpc_endpoint" "mongodb_atlas" {
  vpc_id              = var.vpc_id
  service_name        = var.mongodb_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = false # Atlas uses its own custom DNS; set true only if
                              # the service advertises private DNS zone support

  tags = merge(var.tags, {
    Name = "vpce-mongodb-atlas"
  })
}

###############################################################################
# Route 53 Private Hosted Zone for MongoDB Atlas
#
#    After the endpoint is accepted in Atlas, Atlas provides a private hostname
#    like: <cluster>.<region>.mongodb.net  →  resolves to endpoint ENI IPs
#    Use Atlas-provided DNS or create a private hosted zone that aliases the
#    endpoint DNS name returned below.
###############################################################################

output "mongodb_endpoint_id" {
  description = "VPC endpoint ID – register this in MongoDB Atlas after apply"
  value       = aws_vpc_endpoint.mongodb_atlas.id
}

output "mongodb_endpoint_dns" {
  description = "DNS entries created for the MongoDB Atlas endpoint ENIs"
  value       = aws_vpc_endpoint.mongodb_atlas.dns_entry
}

###############################################################################
# 3. Grafana Cloud Interface Endpoint (PrivateLink)
#
#    - Type: Interface (creates ENIs in your subnets)
#    - After Terraform apply, provide the endpoint ID to Grafana support
#      or accept via the Grafana Cloud portal (depends on your plan)
#    - Configure your OTel/Prometheus/Loki agent to push to the private DNS
#      hostname Grafana provides for the PrivateLink connection
###############################################################################

resource "aws_vpc_endpoint" "grafana_cloud" {
  vpc_id              = var.vpc_id
  service_name        = var.grafana_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true # Grafana Cloud PrivateLink supports private DNS;
                             # set false if you prefer manual DNS management

  tags = merge(var.tags, {
    Name = "vpce-grafana-cloud"
  })
}

output "grafana_endpoint_id" {
  description = "VPC endpoint ID – share with Grafana Cloud to complete the connection"
  value       = aws_vpc_endpoint.grafana_cloud.id
}

output "grafana_endpoint_dns" {
  description = "DNS entries created for the Grafana Cloud endpoint ENIs"
  value       = aws_vpc_endpoint.grafana_cloud.dns_entry
}

###############################################################################
# Example terraform.tfvars (rename to terraform.tfvars and fill in values)
#
# aws_region            = "us-east-1"
# vpc_id                = "vpc-0abc123def456789"
# subnet_ids            = ["subnet-0aaa111", "subnet-0bbb222"]
# route_table_ids       = ["rtb-0ccc333", "rtb-0ddd444"]
# ec2_security_group_id = "sg-0eee555"
# mongodb_service_name  = "com.amazonaws.vpce.us-east-1.vpce-svc-xxxxxxxxxxxxxxxxx"
# grafana_service_name  = "com.amazonaws.vpce.us-east-1.vpce-svc-yyyyyyyyyyyyyyyyy"
# tags = {
#   ManagedBy   = "terraform"
#   Environment = "production"
#   Team        = "platform"
# }
###############################################################################
