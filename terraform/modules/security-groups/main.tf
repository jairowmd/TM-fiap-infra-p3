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