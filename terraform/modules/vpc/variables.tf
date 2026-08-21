# # Primeiro passo: criar variáveis para serem definidas na VPC

# Nome do projeto, usado para compor nomes e tags dos recursos
variable "project_name" {
  description = "Name of the project"
  type        = string
}

# Nome do ambiente (ex: dev, staging, prod)
# Também usado para compor nomes e tags
variable "environment" {
  description = "Environment name"
  type        = string
}

# Bloco CIDR da VPC (faixa de IPs que a rede principal vai usar)
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# Lista de blocos CIDR para subnets públicas
# Cada string representa uma faixa de IP para uma subnet
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

# Lista de blocos CIDR para subnets privadas
# Usadas para recursos internos sem acesso direto à internet
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Lista de zonas de disponibilidade da AWS
# Define em quais datacenters as subnets serão criadas
variable "availability_zones" {
  description = "Availability Zones used by the subnets"
  type        = list(string)
}
