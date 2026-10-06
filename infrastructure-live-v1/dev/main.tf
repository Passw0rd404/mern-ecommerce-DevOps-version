# ============================================================
# PROVIDERS
# ============================================================

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project     = "mern"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront ACM certificates must be created in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "mern"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

provider "grafana" {
  cloud_api_url             = var.grafana_cloud_provider_api_url
  cloud_access_policy_token = var.grafana_cloud_access_policy_token
}

provider "mongodbatlas" {}


# ============================================================
# TERRAFORM / REQUIRED PROVIDERS
# ============================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.7"
    }

    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.13.1"
    }
  }
}


# ============================================================
# VARIABLES
# ============================================================

# -------------------------
# General
# -------------------------

variable "domain_name" {
  description = "Public domain of the site"
  type        = string
}

variable "app_env" {
  description = "Extra non-secret backend environment variables"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "Optional AMI ID. Leave null to use the newest Packer-built AMI."
  type        = string
  default     = null
}


# -------------------------
# MongoDB Atlas
# -------------------------

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}


# -------------------------
# Kashier
# -------------------------

variable "kashier_secret_key" {
  type      = string
  sensitive = true
}

variable "kashier_api_key" {
  type      = string
  sensitive = true
}

variable "kashier_merchant_id" {
  type      = string
  sensitive = true
}


# -------------------------
# Grafana Cloud
# -------------------------

variable "grafana_cloud_access_policy_token" {
  type      = string
  sensitive = true
}

variable "grafana_cloud_provider_api_url" {
  type = string
}

variable "grafana_stack_slug" {
  type = string
}

variable "grafana_external_id" {
  type = string
}

variable "grafana_otlp_endpoint" {
  type = string
}

variable "grafana_otlp_instance_id" {
  type = string
}

variable "grafana_otlp_token" {
  type      = string
  sensitive = true
}

variable "grafana_privatelink_service_name" {
  description = "AWS PrivateLink service name for Grafana Cloud OTLP ingestion"
  type        = string
}


# ============================================================
# LOCALS
# ============================================================

locals {
  domain_name = var.domain_name
  app_port    = 5000
}


# ============================================================
# NETWORK
# ============================================================

module "vpc" {
  source = "../modules/vpc"

  interface_endpoints = {
    grafana = {
      service_name        = var.grafana_privatelink_service_name
      from_port           = 443
      to_port             = 443
      private_dns_enabled = false
    }
  }
}


# ============================================================
# S3
# ============================================================

module "s3" {
  source = "../modules/s3"

  env           = "dev"
  force_destroy = true
}


# ============================================================
# ACM
# ============================================================

module "acm" {
  source = "../modules/acm"

  providers = {
    aws = aws.us_east_1
  }

  domain_name = local.domain_name
}


# ============================================================
# ELASTICACHE
# ============================================================

module "elastic_cache" {
  source = "../modules/elastic_cache"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ec2_sg_id          = module.ec2.security_group_id

  min_replicas = 1
  max_replicas = 3
}


# ============================================================
# MONGODB ATLAS
# ============================================================

module "mongo" {
  source = "../modules/mongo"

  region             = "eu-central-1"
  atlas_org_id       = var.atlas_org_id
  project_name       = "mern-dev"
  cluster_name       = "app"
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
}


# ============================================================
# SECRETS
# ============================================================

module "secrets" {
  source = "../modules/secrets"

  app_port = local.app_port
  app_env  = var.app_env

  # MongoDB
  mongo_uri = module.mongo.connection_uri

  # Redis
  redis_host     = module.elastic_cache.configuration_endpoint_address
  redis_password = module.elastic_cache.auth_token

  # Application URLs
  client_url     = "https://${local.domain_name}"
  cloudfront_url = "https://${local.domain_name}"

  # S3
  uploads_bucket_name = module.s3.app_bucket_name

  # Grafana OTLP
  grafana_otlp_endpoint    = var.grafana_otlp_endpoint
  grafana_otlp_instance_id = var.grafana_otlp_instance_id
  grafana_otlp_token       = var.grafana_otlp_token

  # Kashier
  kashier_secret_key  = var.kashier_secret_key
  kashier_api_key     = var.kashier_api_key
  kashier_merchant_id = var.kashier_merchant_id
}


# ============================================================
# EC2
# ============================================================

module "ec2" {
  source = "../modules/ec2"

  app_port                 = local.app_port
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  private_subnet_ids_by_az = module.vpc.private_subnet_ids_by_az

  ami_id = var.ami_id

  # Secrets Manager
  secret_arn  = module.secrets.secret_arn
  secret_name = module.secrets.secret_name

  # S3
  uploads_bucket_arn     = module.s3.app_bucket_arn
  codedeploy_bucket_name = module.s3.artifacts_bucket_name

  cpu_target = 40
}


# ============================================================
# CLOUD FRONT
# ============================================================

module "cloud_front" {
  source = "../modules/cloud_front"

  # Frontend S3
  frontend_bucket_regional_domain = module.s3.frontend_bucket_regional_domain
  frontend_bucket_id              = module.s3.frontend_bucket_id
  frontend_bucket_arn             = module.s3.frontend_bucket_arn

  # Backend S3
  app_bucket_regional_domain = module.s3.app_bucket_regional_domain
  app_bucket_id              = module.s3.app_bucket_name
  app_bucket_arn             = module.s3.app_bucket_arn

  # S3 VPC endpoint
  app_write_vpce_id = module.vpc.s3_endpoint_id

  # Backend
  vpc_id                = module.vpc.vpc_id
  nlb_arn               = module.ec2.nlb_arn
  nlb_dns_name          = module.ec2.nlb_dns_name
  nlb_security_group_id = module.ec2.nlb_security_group_id

  # Domain / ACM
  aliases             = [local.domain_name]
  acm_certificate_arn = module.acm.certificate_arn
}


# ============================================================
# CODEDEPLOY
# ============================================================

module "code_deploy" {
  source = "../modules/code_deploy"

  autoscaling_group_names = module.ec2.autoscaling_group_names
  target_group_name       = module.ec2.target_group_name
}


# ============================================================
# CLOUDWATCH / GRAFANA AWS OBSERVABILITY
# ============================================================

module "cloud_watch" {
  source = "../modules/cloud_watch"

  grafana_external_id = var.grafana_external_id
}


# ============================================================
# GRAFANA
# ============================================================

module "grafana" {
  source = "../modules/grafana"

  stack_slug          = var.grafana_stack_slug
  cloudwatch_role_arn = module.cloud_watch.role_arn
  aws_regions         = ["eu-central-1"]
}


# ============================================================
# OUTPUTS
# ============================================================

output "cloudfront_domain" {
  value = module.cloud_front.distribution_domain_name
}

output "kvs_arn" {
  value = module.cloud_front.kvs_arn
}

output "artifacts_bucket_name" {
  value = module.s3.artifacts_bucket_name
}

output "codedeploy_app_name" {
  value = module.code_deploy.app_name
}

output "codedeploy_group_name" {
  value = module.code_deploy.deployment_group_name
}
