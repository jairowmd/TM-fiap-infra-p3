# Criação do bucket S3 para armazenar o estado do Terraform
# Output que retorna o nome (ID) do bucket S3 criado
output "bucket_name" {
  description = "Name of the S3 bucket used for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

# Output que retorna o ARN (Amazon Resource Name) do bucket S3 criado
output "bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}