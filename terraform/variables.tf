# Região AWS
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# Nome do projeto
variable "project_name" {
  description = "Name of the project"
  type        = string
}

# Ambiente: dev, staging ou prod
variable "environment" {
  description = "Environment name"
  type        = string
}

# CIDR principal da VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# CIDRs das subnets públicas
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

# CIDRs das subnets privadas
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# Zonas de disponibilidade
variable "availability_zones" {
  description = "Availability Zones used by the subnets"
  type        = list(string)
}

# Versão do Kubernetes usada pelo EKS
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

# Usuários ou roles IAM com acesso administrativo ao EKS
variable "eks_cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin access to the EKS cluster via EKS Access Entries"
  type        = list(string)
}

# Usuário principal dos bancos PostgreSQL
variable "db_username" {
  description = "Master username shared by the PostgreSQL instances"
  type        = string
  default     = "dbadmin"
}

# Senha principal dos bancos PostgreSQL
variable "db_password" {
  description = "Master password for the PostgreSQL instances; set with TF_VAR_db_password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "db_password must contain at least 12 characters."
  }
}

variable "external_secrets_chart_version" {
  description = "External Secrets Helm chart version"
  type        = string
}