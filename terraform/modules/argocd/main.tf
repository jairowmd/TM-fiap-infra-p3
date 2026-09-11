resource "helm_release" "argocd" {
  name       = var.release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  namespace        = var.namespace
  create_namespace = true

  values = [
    file("${path.module}/values.yml")
  ]

  atomic  = true
  wait    = true
  timeout = 600
}