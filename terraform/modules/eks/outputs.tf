# Nome do cluster EKS.
# Usado por: aws eks update-kubeconfig, pipelines de CI/CD, ArgoCD.
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

# ARN do cluster.
output "cluster_arn" {
  description = "ARN do cluster EKS"
  value       = aws_eks_cluster.this.arn
}

# Endpoint da API do Kubernetes.
output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

# Certificado CA (base64) do cluster.
output "cluster_certificate_authority_data" {
  description = "Certificado da autoridade certificadora do cluster EKS (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

# Security Group criada automaticamente pelo EKS para o control plane
output "cluster_security_group_id" {
  description = "ID da Security Group gerenciada automaticamente pelo EKS (control plane + worker nodes)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# URL do OIDC issuer do cluster.
output "cluster_oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster EKS (pré-requisito para IRSA)"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Nome do Managed Node Group.
# Usado por: troubleshooting, observabilidade.
output "node_group_name" {
  description = "Nome do Managed Node Group"
  value       = aws_eks_node_group.this.node_group_name
}

# ARN da IAM Role dos worker nodes.
output "node_role_arn" {
  description = "ARN da IAM Role usada pelos worker nodes do EKS"
  value       = aws_iam_role.eks_node.arn
}

# ARN da IAM Role do control plane.
output "cluster_role_arn" {
  description = "ARN da IAM Role usada pelo control plane do EKS"
  value       = aws_iam_role.eks_cluster.arn
}
