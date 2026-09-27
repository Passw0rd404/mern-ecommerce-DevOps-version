output "role_arn" {
  value      = aws_iam_role.grafana_cloudwatch.arn
  depends_on = [time_sleep.wait_iam_propagation]
}
