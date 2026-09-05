#  Output do Security Group para Banco de Dados
output "database_security_group_id" {
  # Descrição do output, útil para documentação
  description = "Security Group ID for database resources"
  # Valor retornado: o ID do Security Group chamado "database"
  value = aws_security_group.database.id
}

# # Output do Security Group para Redis
output "redis_security_group_id" {
  # Descrição do output
  description = "Security Group ID for Redis resources"
  # Valor retornado: o ID do Security Group chamado "redis"
  value = aws_security_group.redis.id
}
