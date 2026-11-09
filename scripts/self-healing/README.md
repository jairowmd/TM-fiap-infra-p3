# Self-Healing — Runbook Automation

Automação que reage ao alerta e reinicia o deployment com problema, sem
intervenção humana.

```
Falha no auth-service (HTTP 500)
        ↓
Alerta FIRING (Grafana)  ──→  PagerDuty/OpsGenie  ──→  Slack/Discord
        ↓ webhook
API do GitHub (repository_dispatch: self-healing)
        ↓
GitHub Action .github/workflows/self-healing.yml
        ↓ OIDC → role IAM tm-fiap-p4-dev-self-healing
kubectl rollout restart deployment/auth-service
        ↓
Pod novo, sem a falha em memória → taxa de 5xx volta a 0
```

## Peças

| Arquivo | Função |
| --- | --- |
| `services/auth/chaos.go` | Injeta a falha: `/validate` responde 500 até o Pod ser recriado. `/health` continua 200, então o Kubernetes não se cura sozinho. |
| `scripts/self-healing/rollout-restart.sh` | Runbook. Lista permitida de deployments, cooldown de 5 min contra loop de restart, espera o rollout e registra os Pods antes/depois. |
| `.github/workflows/self-healing.yml` | Recebe o webhook (`repository_dispatch`) ou disparo manual e executa o runbook. Ignora alertas `resolved`. |
| `terraform/self-healing-iam.tf` | Role IAM própria via OIDC (só `eks:DescribeCluster`) e EKS Access Entry no grupo `togglemaster-self-healing`. |
| `gitops/k8s/shared/self-healing-rbac.yaml` | RBAC: o grupo só pode dar `get`/`patch` nos 5 deployments do namespace `togglemaster`. |
| `scripts/self-healing/trigger.sh` | Simula o webhook do alerta para testar sem o Grafana. |

## Configuração (uma vez)

1. `terraform apply` para criar a role e o access entry.
2. Conferir que `terraform output -raw self_healing_role_arn` é igual ao
   `SELF_HEALING_ROLE_ARN` fixado no workflow (ARN não é segredo).
3. O ArgoCD aplica o RBAC sozinho (app `shared`) depois do merge na `main`.
4. Criar um token fine-grained no GitHub com acesso a este repositório e
   permissão **Contents: Read and write**. Ele é usado pelo `trigger.sh` e,
   depois, pelo contact point do Grafana.

> O workflow só funciona a partir da `main`: a role confia apenas em tokens OIDC
> com `ref:refs/heads/main`, e o `repository_dispatch` sempre roda na branch padrão.

## Teste local, sem AWS (Kubernetes do Docker Desktop)

Valida o runbook e o RBAC antes de ter o EKS. Ative em Docker Desktop →
Settings → Kubernetes → Enable Kubernetes.

```bash
kubectl config use-context docker-desktop
kubectl create namespace togglemaster
kubectl create deployment auth-service --image=nginx -n togglemaster
kubectl apply -f gitops/k8s/shared/self-healing-rbac.yaml

# RBAC: pode reiniciar os deployments da aplicação, e nada além disso
kubectl auth can-i patch deployment/auth-service -n togglemaster --as=teste --as-group=togglemaster-self-healing   # yes
kubectl auth can-i delete deployment/auth-service -n togglemaster --as=teste --as-group=togglemaster-self-healing  # no
kubectl auth can-i patch deployment/coredns -n kube-system --as=teste --as-group=togglemaster-self-healing         # no

# Runbook: primeira execução reinicia, a segunda respeita o cooldown
./scripts/self-healing/rollout-restart.sh auth-service
./scripts/self-healing/rollout-restart.sh auth-service
./scripts/self-healing/rollout-restart.sh banco-qualquer   # recusado (exit 2)

kubectl delete namespace togglemaster
```

## Teste no EKS sem o alerta

```bash
ALB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
MASTER_KEY=$(kubectl get secret auth-secret -n togglemaster -o jsonpath='{.data.MASTER_KEY}' | base64 -d)

# 1. Injetar a falha
curl -X POST -H "Authorization: Bearer $MASTER_KEY" "http://$ALB/auth/admin/chaos"

# 2. Conferir: /validate responde 500, /health segue 200
curl -i -H "Authorization: Bearer qualquer" "http://$ALB/auth/validate"
curl -i "http://$ALB/auth/health"

# 3. Simular o alerta
GITHUB_TOKEN=<token> ./scripts/self-healing/trigger.sh auth-service AuthService5xx

# 4. Acompanhar o Pod sendo recriado
kubectl get pods -n togglemaster -l app=auth-service -w

# 5. Conferir que voltou: /validate responde 401 (chave inválida), não 500
curl -i -H "Authorization: Bearer qualquer" "http://$ALB/auth/validate"
```

Também dá para rodar pela aba **Actions → Self-Healing → Run workflow**.

## Integração com o alerta (quando o Grafana existir)

Contact point do tipo **Webhook** no Grafana:

- URL: `https://api.github.com/repos/jairowmd/TM-fiap-infra-p3/dispatches`
- Método: `POST`
- Authorization header: `Bearer <token do passo 4>`
- Header extra: `Accept: application/vnd.github+json`
- Custom payload:

```
{
  "event_type": "self-healing",
  "client_payload": {
    "deployment": "{{ index .CommonLabels "deployment" }}",
    "alertname": "{{ index .CommonLabels "alertname" }}",
    "status": "{{ .Status }}"
  }
}
```

A regra de alerta precisa ter o label `deployment` (ex.: `deployment=auth-service`).
Use uma notification policy que mande o alerta para este contact point **e**
para o PagerDuty/OpsGenie (`continue matching`).

## Evidências para o relatório

- Resumo da execução na aba Actions (o runbook escreve os Pods antes/depois).
- `kubectl get pods -w` mostrando o Pod antigo terminando e o novo subindo.
- Log do auth-service com `CHAOS:` antes do restart e sem ele depois.
