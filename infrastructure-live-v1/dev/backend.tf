terraform {
  backend "s3" {
    bucket       = "tfstate-mern-dev"
    key          = "dev/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}
