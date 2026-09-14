# Helm installs this only after the Argo CD CRDs/controller exist.
# A local chart avoids Kubernetes manifest schema discovery during the first plan.
resource "helm_release" "bootstrap" {
  name      = "togglemaster-bootstrap"
  namespace = helm_release.argocd.namespace
  chart     = "${path.module}/bootstrap"

  values = [
    yamlencode({
      repoURL  = var.gitops_repository_url
      revision = "main"
    })
  ]

  depends_on = [helm_release.argocd]

  atomic  = true
  wait    = true
  timeout = 600
}
