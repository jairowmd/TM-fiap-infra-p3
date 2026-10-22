locals {
  loki_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "loki"
  }
}

resource "aws_s3_bucket" "loki" {
  for_each = toset(["chunks", "ruler"])

  bucket_prefix = "${var.project_name}-${var.environment}-loki-${each.key}-"
  force_destroy = false
  tags          = local.loki_tags
}

resource "aws_s3_bucket_public_access_block" "loki" {
  for_each = aws_s3_bucket.loki

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  for_each = aws_s3_bucket.loki

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
