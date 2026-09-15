# # Configuração principal do Terraform
terraform {
  # Define a versão mínima do Terraform necessária para rodar este código
  required_version = ">= 1.5.0"

  # Define os provedores obrigatórios que serão usados
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }

    # Configuração do provedor AWS
    aws = {
      # Fonte oficial do provedor AWS mantido pela HashiCorp
      source = "hashicorp/aws"
      # Versão do provedor: qualquer versão 5.x (compatível com atualizações menores)
      version = "~> 5.0"
    }

    # Provedor do Helm, utilizado na instalaçao do ArgoCD
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
  }
}

# # Configuração do provedor AWS
provider "aws" {
  # Região da AWS onde os recursos serão criados
  # O valor é obtido da variável 'aws_region' definida em variables.tf ou terraform.tfvars
  region = var.aws_region
}


# # Configuração do provedor Helm
provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}