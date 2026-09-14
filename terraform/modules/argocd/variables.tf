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
variable "gitops_repository_url" {
  description = "Git repository containing the Argo CD Applications and Kubernetes manifests"
  type        = string
  default     = "https://github.com/jairowmd/TM-fiap-infra-p3.git"
}
