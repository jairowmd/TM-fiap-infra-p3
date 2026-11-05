#!/usr/bin/env bash
# Simula o webhook do alerta: dispara o workflow de Self-Healing pela API do
# GitHub (repository_dispatch), igual o Grafana fará quando o alerta disparar.
#
# Uso: GITHUB_TOKEN=<token> trigger.sh [deployment] [alertname]
#
# O token precisa da permissão "Contents: Read and write" neste repositório.
set -euo pipefail

DEPLOYMENT="${1:-auth-service}"
ALERTNAME="${2:-ManualTest}"
REPO="${GITHUB_REPOSITORY:-jairowmd/TM-fiap-infra-p3}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Defina GITHUB_TOKEN antes de rodar" >&2
  exit 2
fi

payload=$(cat <<EOF
{
  "event_type": "self-healing",
  "client_payload": {
    "deployment": "$DEPLOYMENT",
    "alertname": "$ALERTNAME",
    "status": "firing"
  }
}
EOF
)

curl -fsS -X POST "https://api.github.com/repos/$REPO/dispatches" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d "$payload"

echo "Self-Healing disparado para $DEPLOYMENT. Acompanhe em https://github.com/$REPO/actions/workflows/self-healing.yml"
