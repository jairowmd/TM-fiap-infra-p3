# # Output do ID da VPC criada
output "vpc_id" {
  # Descrição do output, útil para documentação
  description = "ID of the VPC created for the ToggleMaster project"
  # Valor retornado: o ID da VPC gerada pelo módulo vpc
  value = module.vpc.vpc_id
}

# # Output do Security Group para banco de dados
output "database_security_group_id" {
  # Descrição do output
  description = "Security Group ID for database resources"
  # Valor retornado: o ID do Security Group específico para banco de dados,
  # criado dentro do módulo security_groups
  value = module.security_groups.database_security_group_id
}

# # Output do Security Group para Redis
output "redis_security_group_id" {
  # Descrição do output
  description = "Security Group ID for Redis resources"
  # Valor retornado: o ID do Security Group específico para Redis,
  # também criado dentro do módulo security_groups
  value = module.security_groups.redis_security_group_id
}

# # Outputs do módulo EKS

output "eks_cluster_name" {
  description = "Name of the EKS cluster (used by 'aws eks update-kubeconfig')"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security Group ID managed by EKS (control plane + worker nodes). Pass this as application_security_group_id in the security-groups module to allow the cluster to reach RDS/Redis."
  value       = module.eks.cluster_security_group_id
}

output "eks_node_role_arn" {
  description = "IAM Role ARN used by the EKS worker nodes"
  value       = module.eks.node_role_arn
}
