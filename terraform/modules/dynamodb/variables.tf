variable "project_name" {
  description = "Project name used in tags"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "table_name" {
  description = "Table name required by analytics-service"
  type        = string
  default     = "ToggleMasterAnalytics"
}
