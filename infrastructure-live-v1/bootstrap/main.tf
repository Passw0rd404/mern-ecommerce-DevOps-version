# Apply once, by hand, from your laptop with your own admin AWS login:
#   terraform init
#   terraform apply -var github_repo=OWNER/REPO
# It creates the GitHub trust and the four roles the workflows assume.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}

variable "github_repo" {
  description = "GitHub repository as owner/repo, exact case"
  type        = string
}

variable "project" {
  type    = string
  default = "mern"
}

variable "env" {
  type    = string
  default = "dev"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  owner  = split("/", var.github_repo)[0]
  repo   = split("/", var.github_repo)[1]
  acct   = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.region

  # Bucket names follow the s3 module: <project>-<env>-<account>-<name>
  artifacts_bucket = "${var.project}-${var.env}-${local.acct}-artifacts"
  frontend_bucket  = "${var.project}-${var.env}-${local.acct}-frontend"
  codedeploy       = "arn:aws:codedeploy:${local.region}:${local.acct}"

  # GitHub adds @<id> suffixes to the subject of repos created after 15 July 2026,
  # so every pattern is listed in both forms.
  subject_main = [
    "repo:${local.owner}/${local.repo}:ref:refs/heads/main",
    "repo:${local.owner}@*/${local.repo}@*:ref:refs/heads/main",
    "repo:${local.owner}/${local.repo}:ref:refs/heads/master",
    "repo:${local.owner}@*/${local.repo}@*:ref:refs/heads/master",
  ]
  subject_tags = [
    "repo:${local.owner}/${local.repo}:ref:refs/tags/*",
    "repo:${local.owner}@*/${local.repo}@*:ref:refs/tags/*",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Who may assume a role: runs on main only
data "aws_iam_policy_document" "trust_main" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.subject_main
    }
  }
}

# Who may assume a role: runs on main, or triggered by a published release (a tag)
data "aws_iam_policy_document" "trust_deploy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = concat(local.subject_main, local.subject_tags)
    }
  }
}

# Terraform apply and destroy. Admin, because the stack creates IAM, VPC, CloudFront,
# ElastiCache and more; only runs on main can assume it. Two hours because Atlas,
# CloudFront and NAT make runs long.
resource "aws_iam_role" "terraform" {
  name                 = "gha-terraform"
  max_session_duration = 7200
  assume_role_policy   = data.aws_iam_policy_document.trust_main.json
}

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Packer build and the AMI verify job
resource "aws_iam_role" "packer" {
  name               = "gha-packer"
  assume_role_policy = data.aws_iam_policy_document.trust_main.json
}

resource "aws_iam_role_policy_attachment" "packer_ec2" {
  role       = aws_iam_role.packer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Backend: upload the bundle, start and watch a CodeDeploy deployment
resource "aws_iam_role" "backend_deploy" {
  name               = "gha-backend-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust_deploy.json
}

data "aws_iam_policy_document" "backend_deploy" {
  statement {
    sid       = "Bundle"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion"]
    resources = ["arn:aws:s3:::${local.artifacts_bucket}/backend/*"]
  }

  statement {
    sid       = "CreateDeployment"
    actions   = ["codedeploy:CreateDeployment"]
    resources = ["${local.codedeploy}:deploymentgroup:backend-app/backend-deployment-group"]
  }

  statement {
    sid       = "Revision"
    actions   = ["codedeploy:GetApplicationRevision", "codedeploy:RegisterApplicationRevision"]
    resources = ["${local.codedeploy}:application:backend-app"]
  }

  statement {
    sid       = "DeploymentConfig"
    actions   = ["codedeploy:GetDeploymentConfig"]
    resources = ["${local.codedeploy}:deploymentconfig:*"]
  }

  statement {
    sid       = "WatchDeployment"
    actions   = ["codedeploy:GetDeployment"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "backend_deploy" {
  name   = "backend-deploy"
  role   = aws_iam_role.backend_deploy.id
  policy = data.aws_iam_policy_document.backend_deploy.json
}

# Frontend release and rollback: versioned upload, archive, key-value store switch
resource "aws_iam_role" "frontend_release" {
  name               = "gha-frontend-release"
  assume_role_policy = data.aws_iam_policy_document.trust_deploy.json
}

data "aws_iam_policy_document" "frontend_release" {
  statement {
    sid       = "ListFrontendBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.frontend_bucket}"]
  }

  statement {
    sid       = "FrontendObjects"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.frontend_bucket}/*"]
  }

  statement {
    sid       = "FrontendArchive"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${local.artifacts_bucket}/frontend/*"]
  }

  statement {
    sid = "SwitchVersion"
    actions = [
      "cloudfront-keyvaluestore:DescribeKeyValueStore",
      "cloudfront-keyvaluestore:GetKey",
      "cloudfront-keyvaluestore:ListKeys",
      "cloudfront-keyvaluestore:PutKey",
    ]
    resources = ["arn:aws:cloudfront::${local.acct}:key-value-store/*"]
  }

  statement {
    sid       = "FindKeyValueStore"
    actions   = ["cloudfront:ListKeyValueStores"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "frontend_release" {
  name   = "frontend-release"
  role   = aws_iam_role.frontend_release.id
  policy = data.aws_iam_policy_document.frontend_release.json
}

output "role_arns" {
  value = {
    terraform        = aws_iam_role.terraform.arn
    packer           = aws_iam_role.packer.arn
    backend_deploy   = aws_iam_role.backend_deploy.arn
    frontend_release = aws_iam_role.frontend_release.arn
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-mern-dev"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
