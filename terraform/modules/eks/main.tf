locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "eks"
  }
}

# ============================================================
# EKS Cluster (control plane)
# ============================================================

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.private_subnet_ids
    # SGs extras opcionais; a SG principal do control plane/nodes é
    # criada automaticamente pelo próprio EKS (ver output cluster_security_group_id).
    security_group_ids = var.cluster_additional_security_group_ids

    endpoint_private_access = true
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Habilita o gerenciamento de acesso via EKS Access Entries (API),
  # mantendo compatibilidade com o aws-auth ConfigMap legado.
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# Concede acesso administrativo ao cluster (via EKS Access Entries) para
# os principals informados — ex.: o usuário/role IAM de quem roda o Terraform
# e vai operar o cluster com kubectl.
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# ============================================================
# Managed Node Group (worker nodes)
# ============================================================

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_group_config.instance_types
  capacity_type  = var.node_group_config.capacity_type
  disk_size      = var.node_group_config.disk_size

  scaling_config {
    desired_size = var.node_group_config.desired_size
    min_size     = var.node_group_config.min_size
    max_size     = var.node_group_config.max_size
  }

  labels = {
    project     = var.project_name
    environment = var.environment
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker_policy,
    aws_iam_role_policy_attachment.eks_node_cni_policy,
    aws_iam_role_policy_attachment.eks_node_ecr_readonly,
  ]

  # Evita que o Terraform reverta ajustes de escala feitos em runtime
  # (ex.: Cluster Autoscaler ou ajuste manual via console/CLI).
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ============================================================
# Add-ons do EKS
# ============================================================

# Networking: atribui ENIs/IPs da VPC aos Pods. Obrigatório.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags
}

# Roteamento de Services (iptables/IPVS nos nodes). Obrigatório.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags
}

# DNS interno do cluster (service discovery entre os 5 microsserviços). Obrigatório.
# Depende do Node Group porque os Pods do CoreDNS precisam de um node para rodar.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  depends_on = [aws_eks_node_group.this]
}

# Métricas de CPU/memória para 'kubectl top' e HPA. Opcional.
resource "aws_eks_addon" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  depends_on = [aws_eks_node_group.this]
}
