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

# Versão do Kubernetes usada pelo cluster EKS (módulo eks)
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

# ARNs dos usuários/roles IAM que terão acesso administrativo ao cluster EKS.
# Obrigatório: sem isso, ninguém consegue autenticar via kubectl após o apply.
# Descubra o seu com: aws sts get-caller-identity
variable "eks_cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin access to the EKS cluster via EKS Access Entries"
  type        = list(string)
}
