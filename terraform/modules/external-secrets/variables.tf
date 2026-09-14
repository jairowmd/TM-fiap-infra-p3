variable "release_name" {
  type    = string
  default = "external-secrets"
}

variable "namespace" {
  type    = string
  default = "external-secrets"
}

variable "chart_version" {
  type        = string
  description = "Versão do Helm chart do External Secrets Operator"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC Provider associado ao EKS"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL do cluster EKS"
  type        = string
}

variable "service_account_name" {
  type    = string
  default = "external-secrets"
}

variable "secret_arns" {
  description = "Secrets que o External Secrets Operator pode ler"
  type        = list(string)
}