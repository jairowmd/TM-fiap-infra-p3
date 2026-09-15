locals {
  services = toset([
    "auth",
    "flag",
    "targeting",
    "evaluation",
    "analytics"
  ])
}


module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# Cluster Kubernetes da aplicação.
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version           = var.eks_kubernetes_version
  cluster_admin_principal_arns = var.eks_cluster_admin_principal_arns
}

# Security Groups dos bancos.
# O Security Group do EKS recebe acesso ao PostgreSQL e ao Redis.
module "security_groups" {
  source = "./modules/security-groups"

  project                       = var.project_name
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  enable_application_ingress    = true
  application_security_group_id = module.eks.cluster_security_group_id
}

# Três bancos PostgreSQL:
# auth-service, flag-service e targeting-service.
module "rds" {
  source = "./modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  private_subnet_ids         = module.vpc.private_subnet_ids
  database_security_group_id = module.security_groups.database_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password
}

# Redis usado pelo evaluation-service.
module "elasticache" {
  source = "./modules/elasticache"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = module.vpc.private_subnet_ids
  redis_security_group_id = module.security_groups.redis_security_group_id
}

# DynamoDB usado pelo analytics-service.
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

# Fila usada pelo evaluation-service e pelo analytics-service.
module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
  environment  = var.environment
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [
    module.external_secrets,
    module.aws_load_balancer_controller
  ]
}

module "external_secrets" {
  source = "./modules/external-secrets"

  project_name = var.project_name
  environment  = var.environment

  chart_version = var.external_secrets_chart_version

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url

  secret_arns = [
    module.secrets.secret_arn
  ]

  depends_on = [
    module.eks
  ]
}

# Credenciais e endereços utilizados pelos microsserviços.
module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment

  secret_values = {
    MASTER_KEY = random_password.auth_master_key.result

    DB_USERNAME = var.db_username
    DB_PASSWORD = var.db_password

    AUTH_DATABASE_URL = format(
      "postgres://%s:%s@%s/%s",
      urlencode(var.db_username),
      urlencode(var.db_password),
      module.rds.endpoints.auth,
      module.rds.database_names.auth
    )

    FLAG_DATABASE_URL = format(
      "postgres://%s:%s@%s/%s",
      urlencode(var.db_username),
      urlencode(var.db_password),
      module.rds.endpoints.flag,
      module.rds.database_names.flag
    )

    TARGETING_DATABASE_URL = format(
      "postgres://%s:%s@%s/%s",
      urlencode(var.db_username),
      urlencode(var.db_password),
      module.rds.endpoints.targeting,
      module.rds.database_names.targeting
    )

    REDIS_URL = format(
      "redis://%s:%s",
      module.elasticache.endpoint,
      module.elasticache.port
    )

    AWS_SQS_URL        = module.sqs.queue_url
    AWS_DYNAMODB_TABLE = module.dynamodb.table_name
    AWS_REGION         = var.aws_region
  }
}

module "ecr" {
  for_each = local.services

  source  = "terraform-aws-modules/ecr/aws"
  version = "2.0.0"

  repository_name         = "${var.project_name}-${var.environment}-${each.key}"
  create_lifecycle_policy = false
  repository_force_delete = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = each.key
  }
}
module "aws_load_balancer_controller" {
  source = "./modules/aws-load-balancer-controller"

  project_name      = var.project_name
  environment       = var.environment
  cluster_name      = module.eks.cluster_name
  region            = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  chart_version     = var.aws_load_balancer_controller_chart_version

  depends_on = [module.eks, module.vpc]
}

# Generated once and retained in Terraform state; consumed only by auth.
resource "random_password" "auth_master_key" {
  length  = 48
  special = false
}
