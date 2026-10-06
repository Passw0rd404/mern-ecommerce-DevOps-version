packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "release_version" {
  type        = string
  description = "Version label for this AMI build, for example 1.0.0 or a git commit."
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

locals {
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

source "amazon-ebs" "amazon_linux" {
  ami_name      = "mern-ami-${var.release_version}-${local.timestamp}"
  instance_type = "t3.micro"
  region        = var.region

  # newest Amazon Linux 2023 (x86_64)
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"

  # instances from this AMI must use IMDSv2
  imds_support = "v2.0"

  tags = {
    Release = var.release_version
    Project = "mern"
  }

  snapshot_tags = {
    Release = var.release_version
    Project = "mern"
  }
}

build {
  sources = ["source.amazon-ebs.amazon_linux"]

  provisioner "file" {
    source      = "${path.root}/alloy-config.alloy.tmpl"
    destination = "/tmp/config.alloy.tmpl"
  }

  provisioner "shell" {
    script = "${path.root}/build.sh"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      release = var.release_version
    }
  }
}
