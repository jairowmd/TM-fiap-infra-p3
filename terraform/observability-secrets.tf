# Secret para credenciais da stack de observabilidade (APM New Relic).
#
# O Terraform cria apenas o "container" da secret; o valor NÃO fica no código
# nem no state. Depois do apply, preencha uma vez com:
#
#   aws secretsmanager put-secret-value --region us-east-2 \
#     --secret-id tm-fiap-p4/dev/observability \
#     --secret-string '{"NEW_RELIC_LICENSE_KEY":"<INGEST - LICENSE key>"}'
#
# O External Secrets lê essa secret e cria a Secret "newrelic-license" no
# namespace observability, usada pelo OTel Collector.
resource "aws_secretsmanager_secret" "observability" {
  name                    = "${var.project_name}/${var.environment}/observability"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-observability"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Observability"
  }
}
