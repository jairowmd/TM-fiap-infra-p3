module "vpc" {

  # Terraform, utilize um módulo chamado vpc que esta em ./modules/vpc.
  source = "./modules/vpc"

  # Passa o nome do projeto como variável para o módulo
  project_name = var.project_name
  # Passa o ambiente (dev, staging, prod) como variável para o módulo
  environment  = var.environment
  # CIDR principal da VPC (faixa de IPs)
  vpc_cidr     = var.vpc_cidr
   # Lista de CIDRs para subnets públicas
  public_subnet_cidrs  = var.public_subnet_cidrs
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