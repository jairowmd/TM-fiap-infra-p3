  # Define a versão mínima do Terraform necessária para rodar este código
terraform {
  required_version = ">= 1.5.0"

  # Define os provedores obrigatórios que serão usados
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuração do provedor AWS
provider "aws" {
  region = var.aws_region
}