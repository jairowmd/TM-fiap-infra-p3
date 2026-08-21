# # Declaração das variáveis utilizadas no projeto

# Variável que define a região da AWS onde o backend do Terraform será criado
variable "aws_region" {
  description = "AWS region where the Terraform backend will be created"
  type        = string
}

# Variável que define o nome do projeto
variable "project_name" {
  description = "Name of the project"
  type        = string
}

# Variável que define o ambiente de implantação (ex: dev, staging, prod)
variable "environment" {
  description = "Environment name"
  type        = string
}