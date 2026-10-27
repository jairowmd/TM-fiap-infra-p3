# coloque o nome do bucket criado pelo bootstrap aqui em bucket name

terraform {
  backend "s3" {
    bucket = "tm-fiap-p4-dev-terraform-state"
    key    = "dev/infra-core/terraform.tfstate"
    region = "us-east-2"
  }
}