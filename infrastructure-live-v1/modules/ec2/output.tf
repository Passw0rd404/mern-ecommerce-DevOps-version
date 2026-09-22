output "autoscaling_group_names" {
  description = "One ASG per AZ, for the CodeDeploy deployment group"
  value       = [for asg in aws_autoscaling_group.app : asg.name]
}

output "target_group_name" {
  description = "NLB target group name, for the CodeDeploy deployment group"
  value       = aws_lb_target_group.app.name
}

output "security_group_id" {
  description = "App instance security group (Valkey allows this one)"
  value       = aws_security_group.app.id
}

output "nlb_security_group_id" {
  value = aws_security_group.nlb.id
}

output "nlb_dns_name" {
  value = aws_lb.app.dns_name
}

output "nlb_zone_id" {
  value = aws_lb.app.zone_id
}

output "instance_role_name" {
  value = aws_iam_role.instance.name
}

output "nlb_arn" {
  value = aws_lb.app.arn
}
