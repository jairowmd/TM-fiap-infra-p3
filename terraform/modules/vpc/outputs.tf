# saida de comandos na tela para vizualização ou utilização como "entrada" para outros comandos

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}