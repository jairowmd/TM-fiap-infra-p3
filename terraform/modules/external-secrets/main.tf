resource "helm_release" "external_secrets" {
  name = var.release_name

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

  values = [
    file("${path.module}/values.yml"),

    yamlencode({
      serviceAccount = {
        create = true
        name   = var.service_account_name

        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
        }
      }
    })
  ]

  wait    = true
  atomic  = true
  timeout = 600
}