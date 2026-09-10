variable "project_name" {
  description = "Project name used for the secret path and tags"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secret_values" {
  description = "Connection data and credentials stored as JSON"
  type        = map(string)
  sensitive   = true
}
