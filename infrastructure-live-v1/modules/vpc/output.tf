output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "azs" {
  value = local.azs
}

# The lists follow the AZ order, so they stay stable as you add AZs
output "public_subnet_ids" {
  value = [for az in local.azs : aws_subnet.pub[az].id]
}

output "private_subnet_ids" {
  value = [for az in local.azs : aws_subnet.prv[az].id]
}

output "private_route_table_ids" {
  value = [for az in local.azs : aws_route_table.prv[az].id]
}

output "nat_public_ips" {
  description = "Add these to the MongoDB Atlas IP access list (if you do not use PrivateLink)"
  value       = [for az in local.nat_azs : aws_eip.nat[az].public_ip]
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  value = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "interface_endpoint_dns" {
  value = { for k, v in aws_vpc_endpoint.interface : k => v.dns_entry }
}
