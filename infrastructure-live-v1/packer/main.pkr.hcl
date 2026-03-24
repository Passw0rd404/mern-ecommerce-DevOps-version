packer {
  required_plugins {
    amazon = {
      version = "1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Define the input variable
variable "release_version" {
  type    = string
  description = "The version of the application being baked into the AMI."
}

# Define a timestamp variable for the AMI name
variable "timestamp" {
  type    = string
  default = formatdate("YYYY-MM-DD-hhmm", timestamp())
}

source "amazon-ebs" "amazon_linux" {
  ami_name      = "mern-ami-${var.release_version}-${var.timestamp}"
  instance_type = "t3.micro"
  region        = "eu-north-1"

  # Find the latest Amazon Linux 2023 AMI
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-kernel-6.1-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"] # Amazon's official account ID
  }

  ssh_username = "ec2-user"

  tags = {
    Release = ${var.release_version}
    Project = "mern"
  }
}

build {
  sources = ["source.amazon-ebs.amazon_linux"]

  # Provisioner to run your build script
  provisioner "shell" {
    script = "build.sh"
  }
}
