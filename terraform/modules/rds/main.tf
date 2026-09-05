locals {
  databases = {
    auth = {
      db_name = "auth_db"
      service = "auth-service"
    }
    flag = {
      db_name = "flags_db"
      service = "flag-service"
    }
    targeting = {
      db_name = "targeting_db"
      service = "targeting-service"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}-rds-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-subnets"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Data"
  }
}

resource "aws_db_instance" "this" {
  for_each = local.databases

  identifier             = "${var.project_name}-${var.environment}-${each.key}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = each.value.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-postgres"
    Project     = var.project_name
    Service     = each.value.service
    Environment = var.environment
    Tier        = "Data"
  }
}
