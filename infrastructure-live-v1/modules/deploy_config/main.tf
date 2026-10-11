resource "aws_ssm_parameter" "this" {
  name  = "/mern/${var.env}/deploy-config"
  type  = "String"
  value = jsonencode(var.config)
}
