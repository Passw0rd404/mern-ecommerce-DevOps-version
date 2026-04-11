# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "pub_ids" {
  description = "Public Subnet IDs"
  value       = [for s in aws_subnet.pub : s.id]
}

output "prv_ids" {
  description = "Private Subnet IDs"
  value       = [for s in aws_subnet.prv : s.id]
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app_sg.id
}

output "nat_gateway_ids" {
  description = "Internet Gateway ID"
  value       = [for nat in aws_nat_gateway.nat : nat.id]
}