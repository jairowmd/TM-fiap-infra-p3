# # Saída de comandos na tela para visualização ou utilização como "entrada" em outros módulos/recursos

# Output que retorna o ID da VPC criada
output "vpc_id" {
  # Descrição do output, útil para documentação
  description = "ID of the VPC"
  # Valor retornado: o ID do recurso aws_vpc chamado "this"
  value       = aws_vpc.this.id
}

# Output que retorna os IDs das subnets públicas
output "public_subnet_ids" {
  # Descrição do output
  description = "IDs of the public subnets"
  # Valor retornado: lista de IDs de todas as subnets públicas criadas
  # O operador [*] retorna todos os elementos da lista
  value       = aws_subnet.public[*].id
}

# Output que retorna os IDs das subnets privadas
output "private_subnet_ids" {
  # Descrição do output
  description = "IDs of the private subnets"
  # Valor retornado: lista de IDs de todas as subnets privadas criadas
  value       = aws_subnet.private[*].id
}
