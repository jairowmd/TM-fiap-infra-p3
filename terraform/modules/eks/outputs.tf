# Nome do cluster EKS.
# Usado por: aws eks update-kubeconfig, pipelines de CI/CD, ArgoCD.
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

# ARN do cluster.
# Usado por: políticas IAM/auditoria que precisem referenciar o recurso.
output "cluster_arn" {
  description = "ARN do cluster EKS"
  value       = aws_eks_cluster.this.arn
}

# Endpoint da API do Kubernetes.
# Usado por: kubectl, ArgoCD, providers Terraform kubernetes/helm.
output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

# Certificado CA (base64) do cluster.
# Usado junto com o endpoint para autenticação TLS por quem for
# configurar o provider kubernetes/helm do Terraform ou o ArgoCD.
output "cluster_certificate_authority_data" {
  description = "Certificado da autoridade certificadora do cluster EKS (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

# Security Group criada automaticamente pelo EKS para o control plane,
# e usada por padrão também pelos worker nodes (quando o node group não
# define um launch template customizado, como é o nosso caso).
# Usado por: Integrante 2 (RDS/ElastiCache), como application_security_group_id
# no módulo security-groups, para liberar acesso do cluster ao banco/Redis.
output "cluster_security_group_id" {
  description = "ID da Security Group gerenciada automaticamente pelo EKS (control plane + worker nodes)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# URL do OIDC issuer do cluster.
# Ainda não utilizado nesta fase — é o pré-requisito para configurar
# IRSA (IAM Roles for Service Accounts) mais adiante, quando os 5
# microsserviços precisarem de permissões individuais (ex.: acessar
# Secrets Manager, DynamoDB, SQS).
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
# Usado por: quem for anexar políticas adicionais no futuro
# (ex.: acesso a ECR privado extra, CloudWatch Agent).
output "node_role_arn" {
  description = "ARN da IAM Role usada pelos worker nodes do EKS"
  value       = aws_iam_role.eks_node.arn
}

# ARN da IAM Role do control plane.
# Usado por: auditoria, referência em políticas futuras.
output "cluster_role_arn" {
  description = "ARN da IAM Role usada pelo control plane do EKS"
  value       = aws_iam_role.eks_cluster.arn
}
