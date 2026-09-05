output "queue_url" {
  description = "SQS queue URL consumed by evaluation and analytics services"
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.this.arn
}
