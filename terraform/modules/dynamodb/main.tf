resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name        = var.table_name
    Project     = var.project_name
    Service     = "analytics-service"
    Environment = var.environment
    Tier        = "Data"
  }
}
