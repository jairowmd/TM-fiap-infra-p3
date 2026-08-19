# coloque o nome do bucket criado pelo bootstrap aqui em bucket name

terraform {
  backend "s3" {
    bucket = "tm-fiap-p3-dev-terraform-state-20260819115158628100000001"
    key    = "dev/infra-core/terraform.tfstate"
    region = "us-east-1"
  }
}