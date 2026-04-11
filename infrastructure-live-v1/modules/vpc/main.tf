# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnets
resource "aws_subnet" "pub" {
  for_each = toset(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub_cidrs[index(local.azs, each.key)]
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "pub-subnet-${each.key}"
    Type = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "prv" {
  for_each = toset(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.prv_cidrs[index(local.azs, each.key)]
  availability_zone       = each.value

  tags = {
    Name = "prv-subnet-${each.key}"
    Type = "Private"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "prv" {
  for_each = toset(local.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = {
    Name = "prv-route-table"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "pub-route-table"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "pub" {
  for_each = toset(local.azs)
  subnet_id      = aws_subnet.pub[each.key].id
  route_table_id = aws_route_table.pub.id
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "prv" {
  for_each = toset(local.azs)
  subnet_id      = aws_subnet.prv[each.key].id
  route_table_id = aws_route_table.prv[each.key].id
}

# Elastic ips For The Nats
resource "aws_eip" "eip" {
  for_each = toset(local.azs)
  domain = "vpc"
  tags = {
    Name = "eip-${each.key}"
  }
}

# Nat Gateways
resource "aws_nat_gateway" "nat" {
  for_each = toset(local.azs)
  allocation_id = aws_eip.eip[each.key].id
  subnet_id     = aws_subnet.pub[each.key].id

  tags = {
    Name = "nat-gateway-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Default Security Group - no ingress, allow all egress
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# pub sg
resource "aws_security_group" "pub" {
  name        = "pub-sg"
  description = "Security group for public resources"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "pub-sg"
    Type = "Public"
  }
}

resource "aws_vpc_security_group_ingress_rule" "pub_https" {
  security_group_id = aws_security_group.pub.id
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "pub_http" {
  security_group_id = aws_security_group.pub.id
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "pub_ssh" {
  security_group_id = aws_security_group.pub.id
  description       = "SSH from my IP only"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = local.my_ip  # your IP only
}

resource "aws_vpc_security_group_egress_rule" "pub_all" {
  security_group_id = aws_security_group.pub.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# prv sg
resource "aws_security_group" "prv" {
  name        = "prv-sg"
  description = "Security group for private resources"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "prv-sg"
    Type = "Private"
  }
}

resource "aws_vpc_security_group_ingress_rule" "prv_from_pub" {
  security_group_id            = aws_security_group.prv.id
  description                  = "Allow all traffic from public SG"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.pub.id
}

resource "aws_vpc_security_group_egress_rule" "prv_all" {
  security_group_id = aws_security_group.prv.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}