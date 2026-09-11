resource "helm_release" "external_secrets" {
  name = var.release_name

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

  wait    = true
  atomic  = true
  timeout = 600
}