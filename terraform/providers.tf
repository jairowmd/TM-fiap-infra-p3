# # Configuração principal do Terraform
terraform {
  # Define a versão mínima do Terraform necessária para rodar este código
  required_version = ">= 1.5.0"

  # Define os provedores obrigatórios que serão usados
  required_providers {
    # Configuração do provedor AWS
    aws = {
      # Fonte oficial do provedor AWS mantido pela HashiCorp
      source = "hashicorp/aws"
      # Versão do provedor: qualquer versão 5.x (compatível com atualizações menores)
      version = "~> 5.0"
    }
  }
}

# # Configuração do provedor AWS
provider "aws" {
  # Região da AWS onde os recursos serão criados
  # O valor é obtido da variável 'aws_region' definida em variables.tf ou terraform.tfvars
  region = var.aws_region
}
