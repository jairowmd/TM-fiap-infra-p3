output "endpoints" {
  description = "RDS endpoints, including the PostgreSQL port, keyed by service"
  value       = { for key, instance in aws_db_instance.this : key => instance.endpoint }
}

output "database_names" {
  description = "Database names keyed by service"
  value       = { for key, config in local.databases : key => config.db_name }
}
