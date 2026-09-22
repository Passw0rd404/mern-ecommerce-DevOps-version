provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project     = "mern"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.7"
    }
  }
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

# API keys come from MONGODB_ATLAS_PUBLIC_API_KEY and MONGODB_ATLAS_PRIVATE_API_KEY
provider "mongodbatlas" {}


module "code_deploy" {
  source                  = "../modules/code_deploy"
  autoscaling_group_names = module.ec2.autoscaling_group_names
  target_group_name       = module.ec2.target_group_name
}

module "vpc" {
  source = "../modules/vpc"
  interface_endpoints = {
    atlas = {
      service_name        = module.mongo.privatelink_service_name
      from_port           = 1024
      to_port             = 65535
      private_dns_enabled = false
    }
  }
  az_num             = 2
  single_nat_gateway = true # cheap for dev. Set false for one NAT per AZ.
}

module "s3" {
  source = "../modules/s3"

  env           = "dev"
  force_destroy = true # dev only, see the destroy section below
}

variable "domain_name" {
  description = "Public domain of the site (from terraform.tfvars)"
  type        = string
}

variable "app_env" {
  description = "Extra non-secret backend environment variables (from terraform.tfvars)"
  type        = map(string)
  default     = {}
}

locals {
  domain_name = var.domain_name
  app_port    = 5000
}

# CloudFront certificates must live in us-east-1
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

module "acm" {
  source    = "../modules/acm"
  providers = { aws = aws.us_east_1 }

  domain_name = local.domain_name
}

module "cloud_front" {
  source = "../modules/cloud_front"

  frontend_bucket_regional_domain = module.s3.frontend_bucket_regional_domain
  frontend_bucket_id              = module.s3.frontend_bucket_id
  frontend_bucket_arn             = module.s3.frontend_bucket_arn
  app_bucket_regional_domain      = module.s3.app_bucket_regional_domain
  app_bucket_id                   = module.s3.app_bucket_name
  app_bucket_arn                  = module.s3.app_bucket_arn
  app_write_vpce_id               = module.vpc.s3_endpoint_id

  vpc_id                = module.vpc.vpc_id
  nlb_arn               = module.ec2.nlb_arn
  nlb_dns_name          = module.ec2.nlb_dns_name
  nlb_security_group_id = module.ec2.nlb_security_group_id

  aliases             = [local.domain_name]
  acm_certificate_arn = module.acm.certificate_arn
}

output "cloudfront_domain" {
  value = module.cloud_front.distribution_domain_name
}

output "kvs_arn" {
  value = module.cloud_front.kvs_arn
}

module "elastic_cache" {
  source = "../modules/elastic_cache"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ec2_sg_id          = module.ec2.security_group_id

  min_replicas = 1
  max_replicas = 3
}

module "mongo" {
  source = "../modules/mongo"

  region          = "eu-north-1"
  atlas_org_id    = var.atlas_org_id
  project_name    = "mern-dev"
  cluster_name    = "app"
  vpc_endpoint_id = module.vpc.interface_endpoint_ids["atlas"]
}

variable "stripe_secret_key" {
  description = "Stripe secret key (TF_VAR_stripe_secret_key in CI)"
  type        = string
  sensitive   = true
}


variable "ami_id" {
  description = "Optional AMI id. Leave null to use the newest Packer-built AMI."
  type        = string
  default     = null
}

module "secrets" {
  source = "../modules/secrets"
  app_port            = local.app_port
  app_env             = var.app_env
  mongo_uri           = module.mongo.connection_uri
  redis_host          = module.elastic_cache.configuration_endpoint_address
  redis_password      = module.elastic_cache.auth_token
  stripe_secret_key   = var.stripe_secret_key
  client_url          = "https://${local.domain_name}"
  uploads_bucket_name = module.s3.app_bucket_name
  cloudfront_url      = "https://${local.domain_name}" # rename to your cloud_front output
}

module "ec2" {
  source = "../modules/ec2"

  app_port               = local.app_port
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  private_subnet_ids_by_az = module.vpc.private_subnet_ids_by_az

  ami_id                 = var.ami_id
  secret_arn             = module.secrets.secret_arn
  secret_name            = module.secrets.secret_name
  uploads_bucket_arn     = module.s3.app_bucket_arn # rename to your s3 output
  codedeploy_bucket_name = module.s3.artifacts_bucket_name
  cpu_target             = 40 # fork mode: one saturated core is ~50% of a 2 vCPU box

}
output "artifacts_bucket_name" { value = module.s3.artifacts_bucket_name }
output "codedeploy_app_name" { value = module.code_deploy.app_name }
output "codedeploy_group_name" { value = module.code_deploy.deployment_group_name }
