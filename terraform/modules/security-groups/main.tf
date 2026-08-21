# Security Group para Banco de Dados
resource "aws_security_group" "database" {
  name        = "${var.project}-${var.environment}-database-sg"
  description = "Security group for database resources"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project}-${var.environment}-database-sg"
    Project     = var.project
    Environment = var.environment
    Tier        = "Data"
  }
}

# Permite PostgreSQL apenas quando um SG da aplicação for informado
resource "aws_vpc_security_group_ingress_rule" "database_postgres" {
  count = var.application_security_group_id != null ? 1 : 0

  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.application_security_group_id

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  description = "Allow PostgreSQL access from application security group"
}


# Security Group para Redis
resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "Security group for Redis resources"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project}-${var.environment}-redis-sg"
    Project     = var.project
    Environment = var.environment
    Tier        = "Data"
  }
}

# Permite Redis apenas quando um SG da aplicação for informado
resource "aws_vpc_security_group_ingress_rule" "redis" {
  count = var.application_security_group_id != null ? 1 : 0

  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = var.application_security_group_id

  ip_protocol = "tcp"
  from_port   = 6379
  to_port     = 6379

  description = "Allow Redis access from application security group"
}
