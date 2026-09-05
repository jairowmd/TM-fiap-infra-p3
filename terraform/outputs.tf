# # Output do ID da VPC criada
output "vpc_id" {
  # Descrição do output, útil para documentação
  description = "ID of the VPC created for the ToggleMaster project"
  # Valor retornado: o ID da VPC gerada pelo módulo vpc
  value = module.vpc.vpc_id
}

# # Output do Security Group para banco de dados
output "database_security_group_id" {
  # Descrição do output
  description = "Security Group ID for database resources"
  # Valor retornado: o ID do Security Group específico para banco de dados,
  # criado dentro do módulo security_groups
  value = module.security_groups.database_security_group_id
}

# # Output do Security Group para Redis
output "redis_security_group_id" {
  # Descrição do output
  description = "Security Group ID for Redis resources"
  # Valor retornado: o ID do Security Group específico para Redis,
  # também criado dentro do módulo security_groups
  value = module.security_groups.redis_security_group_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs created by the VPC module"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs consumed directly by RDS and ElastiCache"
  value       = module.vpc.private_subnet_ids
}

output "rds_endpoints" {
  description = "PostgreSQL endpoints keyed by auth, flag and targeting"
  value       = module.rds.endpoints
}

output "redis_endpoint" {
  description = "Redis hostname"
  value       = module.elasticache.endpoint
}

output "dynamodb_table" {
  description = "DynamoDB table used by analytics-service"
  value       = module.dynamodb.table_name
}

output "sqs_queue_url" {
  description = "SQS queue URL used by evaluation-service and analytics-service"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = module.sqs.queue_arn
}

output "data_services_secret_arn" {
  description = "Secrets Manager ARN containing data-service connection values"
  value       = module.secrets.secret_arn
}
