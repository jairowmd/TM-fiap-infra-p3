
# Crie um recurso AWS do tipo aws_vpc. O nome interno dele no Terraform será: aws_vpc.this
resource "aws_vpc" "this" {
  # pegando o valor da variável vpc_cidr definida nas variables.tf
  cidr_block = var.vpc_cidr


  # As tags são metadados, ou seja, informações que colocamos nos recursos AWS para identificá-los e organizá-los.
  tags = {

    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment

  }

}