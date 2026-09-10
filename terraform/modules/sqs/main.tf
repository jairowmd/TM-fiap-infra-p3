resource "aws_sqs_queue" "this" {
  name                       = "ToggleMasterQueue-${var.environment}"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true

  tags = {
    Name        = "ToggleMasterQueue"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Messaging"
  }
}
