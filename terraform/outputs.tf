# # Output do ID da VPC criada
output "vpc_id" {
  # Descrição do output, útil para documentação
  description = "ID of the VPC created for the ToggleMaster project"
  # Valor retornado: o ID da VPC gerada pelo módulo vpc
  value       = module.vpc.vpc_id
}

# # Output do Security Group para banco de dados
output "database_security_group_id" {
  # Descrição do output
  description = "Security Group ID for database resources"
  # Valor retornado: o ID do Security Group específico para banco de dados,
  # criado dentro do módulo security_groups
  value       = module.security_groups.database_security_group_id
}

# # Output do Security Group para Redis
output "redis_security_group_id" {
  # Descrição do output
  description = "Security Group ID for Redis resources"
  # Valor retornado: o ID do Security Group específico para Redis,
  # também criado dentro do módulo security_groups
  value       = module.security_groups.redis_security_group_id
}
