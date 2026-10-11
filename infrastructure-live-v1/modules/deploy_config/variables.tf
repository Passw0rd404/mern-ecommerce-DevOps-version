variable "env" {
  description = "Environment name (dev, staging, prod). Becomes part of the parameter name."
  type        = string
}

variable "config" {
  description = "Key/value pairs the deploy workflows export as env vars"
  type        = map(string)
}
