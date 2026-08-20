output "vpc_id" {
  description = "ID of the VPC created for the ToggleMaster project"
  value       = module.vpc.vpc_id
}