# # Declaração das variáveis utilizadas no projeto

# Variável que define a região da AWS onde os recursos serão criados
variable "aws_region" {
  # Descrição da variável, útil para documentação
  description = "AWS region where resources will be created"
  # Tipo da variável: string (texto)
  type = string
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

# Variável que define o bloco CIDR da VPC (faixa de IPs da rede principal)
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# Variável que define os blocos CIDR das subnets públicas
# É uma lista de strings, cada uma representando uma faixa de IP
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

# Variável que define os blocos CIDR das subnets privadas
# Também é uma lista de strings
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Variável que define as zonas de disponibilidade da AWS
# É uma lista de strings, cada uma representando uma AZ (ex: us-east-1a, us-east-1b)
variable "availability_zones" {
  description = "Availability Zones used by the subnets"
  type        = list(string)
}

variable "application_security_group_id" {
  description = "Security Group used by EKS/application workloads; when set, it receives access to PostgreSQL and Redis"
  type        = string
  default     = null
  nullable    = true
}

variable "db_username" {
  description = "Master username shared by the study PostgreSQL instances"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for the study PostgreSQL instances; set with TF_VAR_db_password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "db_password must contain at least 12 characters."
  }
}
