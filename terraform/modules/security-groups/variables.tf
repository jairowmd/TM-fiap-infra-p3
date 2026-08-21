# # Declaração das variáveis utilizadas para os Security Groups

# Variável que define o nome do projeto
# Usada para compor nomes e tags dos recursos
variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

# Variável que define o ambiente de implantação (ex: dev, staging, prod)
# Também usada para compor nomes e tags
variable "environment" {
  description = "Environment name"
  type        = string
}

# Variável que define o ID da VPC
# É necessário para criar os Security Groups dentro da VPC correta
variable "vpc_id" {
  description = "VPC ID where the Security Groups will be created"
  type        = string
}

variable "application_security_group_id" {
  description = "Security Group ID allowed to access database and Redis"
  type        = string
  default     = null
}