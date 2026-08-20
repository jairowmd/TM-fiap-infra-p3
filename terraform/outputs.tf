output "vpc_id" {
  description = "ID of the VPC created for the ToggleMaster project"
  value       = module.vpc.vpc_id
}

output "database_security_group_id" {
  description = "Security Group ID for database resources"
  value       = module.security_groups.database_security_group_id
}

output "redis_security_group_id" {
  description = "Security Group ID for Redis resources"
  value       = module.security_groups.redis_security_group_id
}