resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.project_name}/${var.environment}/data-services"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-services"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Data"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secret_values)
}
