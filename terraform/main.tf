module "vpc" {

  # Terraform, utilize um módulo chamado vpc que esta em ./modules/vpc.
  source = "./modules/vpc"

  # Passa o nome do projeto como variável para o módulo
  project_name = var.project_name
  # Passa o ambiente (dev, staging, prod) como variável para o módulo
  environment = var.environment
  # CIDR principal da VPC (faixa de IPs)
  vpc_cidr = var.vpc_cidr
  # Lista de CIDRs para subnets públicas
  public_subnet_cidrs = var.public_subnet_cidrs
  # Lista de CIDRs para subnets privadas
  private_subnet_cidrs = var.private_subnet_cidrs
  # Zonas de disponibilidade da AWS onde os recursos serão criados
  availability_zones = var.availability_zones
}


# Terraform, utilize um módulo chamado security_groups que esta em ./modules/security-groups.
module "security_groups" {
  source = "./modules/security-groups"

  project     = var.project_name
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# Terraform, utilize um módulo chamado eks que esta em ./modules/eks.
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment

  # Rede recebida do módulo vpc.
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version = var.eks_kubernetes_version

  # Sem isto, ninguém consegue autenticar no cluster via kubectl após o apply.
  cluster_admin_principal_arns = var.eks_cluster_admin_principal_arns
}