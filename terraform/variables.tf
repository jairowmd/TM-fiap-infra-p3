# Região AWS
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
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
  default     = "ToggleMaster_DB#2026!"

  validation {
    condition = (
      length(var.db_password) >= 12 &&
      length(var.db_password) <= 128 &&
      can(regex("^[!-~]+$", var.db_password)) &&
      length(regexall("[/@\"]", var.db_password)) == 0
    )
    error_message = "db_password must be 12-128 printable ASCII characters, excluding spaces, /, @, and double quotes."
  }
}

# Token do GitHub usado pelo contact point de Self-Healing do Grafana para
# disparar o workflow (repository_dispatch). Vazio = webhook sem autenticação.
variable "github_dispatch_token" {
  description = "Fine-grained GitHub token (Contents: Read and write on this repo) for the Grafana self-healing webhook; set with TF_VAR_github_dispatch_token"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.github_dispatch_token == "" || can(regex("^(github_pat_|ghp_)[A-Za-z0-9_]+$", var.github_dispatch_token))
    error_message = "github_dispatch_token must be empty or a GitHub token (github_pat_... or ghp_...)."
  }
}

variable "external_secrets_chart_version" {
  description = "External Secrets Helm chart version (>= 0.17, the manifests use external-secrets.io/v1)"
  type        = string
  default     = "2.14.0"
}
variable "aws_load_balancer_controller_chart_version" {
  description = "Controller chart version; update the vendored IAM policy when upgrading"
  type        = string
  default     = "1.14.1"
}
