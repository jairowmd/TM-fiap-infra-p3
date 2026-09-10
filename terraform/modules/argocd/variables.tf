variable "namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD Helm Chart version"
  type        = string
  default     = "10.8.4"
}