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
    error_message = "ElastiCache requires at least two private subnets for this project."
  }
}

variable "redis_security_group_id" {
  description = "Security Group ID attached to the Redis cluster"
  type        = string
}
