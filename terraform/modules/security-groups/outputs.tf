output "database_security_group_id" {
  description = "Security Group ID for database resources"
  value       = aws_security_group.database.id
}

output "redis_security_group_id" {
  description = "Security Group ID for Redis resources"
  value       = aws_security_group.redis.id
}