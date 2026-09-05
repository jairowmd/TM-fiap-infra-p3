output "secret_arn" {
  description = "ARN of the data services secret"
  value       = aws_secretsmanager_secret.this.arn
}
