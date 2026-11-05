# Role assumida pelo workflow .github/workflows/self-healing.yml.
# Separada da role de CI: só enxerga o cluster EKS e, dentro dele, só pode
# reiniciar os deployments do namespace togglemaster (RBAC em
# gitops/k8s/shared/self-healing-rbac.yaml).
resource "aws_iam_role" "self_healing" {
  name = "${var.project_name}-${var.environment}-self-healing"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.github_actions_main_sub
        }
      }
    }]
  })
}

# Necessário para o "aws eks update-kubeconfig"
resource "aws_iam_role_policy" "self_healing_eks" {
  name = "${var.project_name}-${var.environment}-self-healing-eks"
  role = aws_iam_role.self_healing.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = module.eks.cluster_arn
    }]
  })
}

# Mapeia a role para o grupo Kubernetes usado no RoleBinding.
# Sem access policy da AWS: as permissões vêm só do RBAC do namespace.
resource "aws_eks_access_entry" "self_healing" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_role.self_healing.arn
  kubernetes_groups = ["togglemaster-self-healing"]
}
