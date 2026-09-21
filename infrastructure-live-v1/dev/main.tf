provider "aws" {
  region = "eu-north-1"
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

default_tags {
    tags = {
      Project     = "mern"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "code_deploy" {
  source                 = "../modules/code_deploy"
  autoscaling_group_name = module.ec2.autoscaling_group_name
  target_group_name      = module.ec2.target_group_name
}

module "vpc" {
  source = "../modules/vpc"

  az_num             = 2
  single_nat_gateway = true # cheap for dev. Set false for one NAT per AZ.
}

module "s3" {
  source = "../modules/s3"

  env = "dev"
  force_destroy = true # dev only, see the destroy section below
}

locals {
  domain_name = "dev.abdullahsameh.tech"
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

variable "client_url" {
  description = "Public URL of the site"
  type        = string
}

variable "codedeploy_bucket_name" {
  description = "Bucket where CI stores the CodeDeploy bundles"
  type        = string
}

variable "ami_id" {
  description = "Optional AMI id. Leave null to use the newest Packer-built AMI."
  type        = string
  default     = null
}

module "secrets" {
  source = "../modules/secrets"

  mongo_uri           = module.mongo.connection_uri
  redis_host          = module.elastic_cache.configuration_endpoint_address
  redis_password      = module.elastic_cache.auth_token
  stripe_secret_key   = var.stripe_secret_key
  client_url          = var.client_url
  uploads_bucket_name = module.s3.uploads_bucket_name        # rename to your s3 output
  cloudfront_url      = "https://${module.cloud_front.domain_name}" # rename to your cloud_front output
}

module "ec2" {
  source = "../modules/ec2"

  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  public_subnet_ids        = module.vpc.public_subnet_ids
  private_subnet_ids_by_az = module.vpc.private_subnet_ids_by_az

  ami_id                 = var.ami_id
  secret_arn             = module.secrets.secret_arn
  secret_name            = module.secrets.secret_name
  uploads_bucket_arn     = module.s3.uploads_bucket_arn # rename to your s3 output
  codedeploy_bucket_name = var.codedeploy_bucket_name
}

module "code_deploy" {
  source = "../modules/code_deploy"

  autoscaling_group_names = module.ec2.autoscaling_group_names
  target_group_name       = module.ec2.target_group_name
}
