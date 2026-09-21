data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_num)

  # AZ name -> position, for example { "eu-north-1a" = 0, "eu-north-1b" = 1 }
  # Adding an AZ appends a new key, so existing resources are not touched.
  az_index = { for i, az in local.azs : az => i }

  # Automatic subnets (with a /16 VPC): public 10.0.0.0/24, 10.0.1.0/24 ...
  # private 10.0.10.0/24, 10.0.11.0/24 ...
  pub_cidrs = length(var.pub_cidrs) > 0 ? var.pub_cidrs : [for i in range(var.az_num) : cidrsubnet(var.vpc_cidr, 8, i)]
  prv_cidrs = length(var.prv_cidrs) > 0 ? var.prv_cidrs : [for i in range(var.az_num) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  # Which AZs get a NAT gateway
  nat_azs = var.single_nat_gateway ? [local.azs[0]] : local.azs
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "main-igw" }
}

# Subnets: one public and one private per AZ
resource "aws_subnet" "pub" {
  for_each = local.az_index

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.pub_cidrs[each.value]
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "pub-subnet-${each.key}"
    Type = "Public"
  }
}

resource "aws_subnet" "prv" {
  for_each = local.az_index

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.prv_cidrs[each.value]
  availability_zone = each.key

  tags = {
    Name = "prv-subnet-${each.key}"
    Type = "Private"
  }
}

# NAT gateways (one per AZ, or a single one when single_nat_gateway = true)
resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"

  tags = { Name = "nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "nat" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.pub[each.key].id

  tags = { Name = "nat-${each.key}" }

  depends_on = [aws_internet_gateway.main]
}

# Public route table (shared by all public subnets)
resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "pub-rt" }
}

resource "aws_route_table_association" "pub" {
  for_each = local.az_index

  subnet_id      = aws_subnet.pub[each.key].id
  route_table_id = aws_route_table.pub.id
}

# Private route tables (one per AZ, each pointing to its own or the shared NAT)
resource "aws_route_table" "prv" {
  for_each = local.az_index

  vpc_id = aws_vpc.main.id

  tags = { Name = "prv-rt-${each.key}" }
}

resource "aws_route" "prv_nat" {
  for_each = local.az_index

  route_table_id         = aws_route_table.prv[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[var.single_nat_gateway ? local.azs[0] : each.key].id
}

resource "aws_route_table_association" "prv" {
  for_each = local.az_index

  subnet_id      = aws_subnet.prv[each.key].id
  route_table_id = aws_route_table.prv[each.key].id
}

# Default security group: no rules at all (nothing should use it)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}
