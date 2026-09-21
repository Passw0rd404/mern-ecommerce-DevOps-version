# S3 gateway endpoint (free). Traffic to S3 stays on the AWS network.
# No custom policy on purpose: the default allows all S3 access through the
# endpoint, and your IAM roles and bucket policies do the real restricting.
# If you ever add a policy, it must still allow the AL2023 package repositories,
# the aws-codedeploy-* buckets and your bundle bucket (including
# s3:GetObjectVersion), or package installs and deployments will break.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.prv : rt.id]

  tags = { Name = "vpce-s3" }
}

# Extra interface endpoints (MongoDB Atlas, Grafana Cloud, ...), from var.interface_endpoints
resource "aws_security_group" "interface_endpoint" {
  for_each = var.interface_endpoints

  name        = "vpce-${each.key}-sg"
  description = "Access to the ${each.key} interface endpoint from inside the VPC"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "vpce-${each.key}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoint" {
  for_each = var.interface_endpoints

  security_group_id = aws_security_group.interface_endpoint[each.key].id
  description       = "From inside the VPC"
  ip_protocol       = "tcp"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = aws_vpc.main.cidr_block
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.prv : s.id]
  security_group_ids  = [aws_security_group.interface_endpoint[each.key].id]
  private_dns_enabled = each.value.private_dns_enabled

  tags = { Name = "vpce-${each.key}" }
}
