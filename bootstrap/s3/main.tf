
# Cria um bucket S3 que será usado para armazenar o Terraform state
# bucket_prefix: gera um nome único para o bucket baseado no projeto e ambiente, garantindo que não haja conflito.
# tags: adiciona metadados úteis para identificar o recurso (nome, projeto, ambiente, responsável e propósito).
resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "${var.project_name}-${var.environment}-terraform-state-"

  tags = {
    Name        = "${var.project_name}-${var.environment}-terraform-state"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Terraform State"
  }
}

# Configurações garante que o bucket não possa ser exposto publicamente.:

# block_public_acls: bloqueia ACLs públicas.

# block_public_policy: bloqueia políticas públicas.

# ignore_public_acls: ignora qualquer ACL pública aplicada.

# restrict_public_buckets: impede que o bucket seja tornado público.

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# O versionamento garante segurança e rastreabilidade das mudanças.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}