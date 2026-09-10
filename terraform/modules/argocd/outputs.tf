output "namespace" {
  description = "ArgoCD namespace"
  value       = helm_release.argocd.namespace
}

output "release_name" {
  description = "ArgoCD Helm release name"
  value       = helm_release.argocd.name
}

output "status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}