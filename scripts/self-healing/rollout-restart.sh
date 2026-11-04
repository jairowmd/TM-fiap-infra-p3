#!/usr/bin/env bash
# Runbook de Self-Healing: reinicia um deployment do ToggleMaster e espera o
# rollout terminar. Chamado pelo workflow .github/workflows/self-healing.yml,
# mas também roda manualmente com um kubeconfig válido.
#
# Uso: rollout-restart.sh <deployment> [namespace]
#
# Variáveis opcionais:
#   COOLDOWN_SECONDS  janela em que um novo restart é ignorado (padrão 300)
#   ROLLOUT_TIMEOUT   tempo máximo de espera do rollout (padrão 180s)
set -euo pipefail

DEPLOYMENT="${1:-}"
NAMESPACE="${2:-togglemaster}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"

# Só os deployments da aplicação podem ser reiniciados pela automação.
ALLOWED_DEPLOYMENTS="auth-service flag-service targeting-service evaluation-service analytics-service"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

if [[ -z "$DEPLOYMENT" ]]; then
  echo "Uso: $0 <deployment> [namespace]" >&2
  exit 2
fi

if [[ " $ALLOWED_DEPLOYMENTS " != *" $DEPLOYMENT "* ]]; then
  log "ERRO: '$DEPLOYMENT' não está na lista permitida ($ALLOWED_DEPLOYMENTS)" >&2
  exit 2
fi

if [[ "$NAMESPACE" != "togglemaster" ]]; then
  log "ERRO: namespace '$NAMESPACE' não permitido" >&2
  exit 2
fi

log "Self-Healing iniciado para deployment/$DEPLOYMENT (namespace $NAMESPACE)"

# Idempotência: se houve restart recente, não reinicia de novo. Evita loop
# quando o alerta continua FIRING enquanto o Pod novo ainda está subindo.
last_restart="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.metadata.annotations.kubectl\.kubernetes\.io/restartedAt}')"

if [[ -n "$last_restart" ]]; then
  elapsed=$(( $(date -u +%s) - $(date -u -d "$last_restart" +%s) ))
  if (( elapsed < COOLDOWN_SECONDS )); then
    log "Último restart há ${elapsed}s (cooldown ${COOLDOWN_SECONDS}s). Nada a fazer."
    exit 0
  fi
  log "Último restart: $last_restart (${elapsed}s atrás)"
fi

log "Pods antes do restart:"
kubectl get pods -n "$NAMESPACE" -l "app=$DEPLOYMENT" -o wide

log "Executando: kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE"
kubectl rollout restart "deployment/$DEPLOYMENT" -n "$NAMESPACE"

if ! kubectl rollout status "deployment/$DEPLOYMENT" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"; then
  log "ERRO: rollout não terminou em $ROLLOUT_TIMEOUT. Escalar para o plantão." >&2
  kubectl get pods -n "$NAMESPACE" -l "app=$DEPLOYMENT" -o wide >&2
  exit 1
fi

log "Pods depois do restart:"
kubectl get pods -n "$NAMESPACE" -l "app=$DEPLOYMENT" -o wide

log "Self-Healing concluído: deployment/$DEPLOYMENT recriado com sucesso"
