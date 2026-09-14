variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs created by the VPC module"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS requires at least two private subnets in different Availability Zones."
  }
}

variable "database_security_group_id" {
  description = "Security Group ID attached to the PostgreSQL instances"
  type        = string
}

variable "db_username" {
  description = "Master username shared by the study databases"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password supplied securely at runtime"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.db_password) >= 12 &&
      length(var.db_password) <= 128 &&
      can(regex("^[!-~]+$", var.db_password)) &&
      length(regexall("[/@\"]", var.db_password)) == 0
    )
    error_message = "db_password must be 12-128 printable ASCII characters, excluding spaces, /, @, and double quotes."
  }

}
