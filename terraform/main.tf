module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security_groups" {
  source = "./modules/security-groups"

  project                       = var.project_name
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  application_security_group_id = var.application_security_group_id
}

# The data layer consumes networking outputs directly. No subnet or Security
# Group ID needs to be copied into terraform.tfvars.
module "rds" {
  source = "./modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  private_subnet_ids         = module.vpc.private_subnet_ids
  database_security_group_id = module.security_groups.database_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = module.vpc.private_subnet_ids
  redis_security_group_id = module.security_groups.redis_security_group_id
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
  environment  = var.environment
}

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  secret_values = {
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

    REDIS_URL          = format("redis://%s:%s", module.elasticache.endpoint, module.elasticache.port)
    AWS_SQS_URL        = module.sqs.queue_url
    AWS_DYNAMODB_TABLE = module.dynamodb.table_name
    AWS_REGION         = var.aws_region
  }
}
