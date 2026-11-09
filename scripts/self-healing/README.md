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
| `gitops/observability/grafana/alerting/self-healing.yaml` | Regra `AuthService5xx` (5xx > 5% por 1 min) e contact point `self-healing-github`, provisionados pelo sidecar de alertas do Grafana. |
| `gitops/observability/grafana/external-secret.yaml` | ExternalSecret `grafana-self-healing`: leva o `GITHUB_DISPATCH_TOKEN` do Secrets Manager para o Grafana. |
| `terraform/variables.tf` (`github_dispatch_token`) | Grava o token no secret `tm-fiap-p4/dev/data-services`. |

## Configuração (uma vez)

1. `terraform apply` para criar a role e o access entry.
2. Conferir que `terraform output -raw self_healing_role_arn` é igual ao
   `SELF_HEALING_ROLE_ARN` fixado no workflow (ARN não é segredo).
3. O ArgoCD aplica o RBAC sozinho (app `shared`) depois do merge na `main`.
4. Criar o token do GitHub (passo a passo abaixo) e aplicar com
   `TF_VAR_github_dispatch_token`. O `terraform apply` grava o token no Secrets
   Manager, o ExternalSecret o entrega ao Grafana em até 1h (ou na hora, com
   `kubectl annotate externalsecret grafana-self-healing -n observability force-sync=$(date +%s) --overwrite`)
   e o Grafana precisa ser reiniciado para ler a variável:
   `kubectl rollout restart deployment/kube-prometheus-stack-grafana -n observability`.

### Token do GitHub

O repositório pertence à conta pessoal `jairowmd`. Token fine-grained só acessa
repositórios do próprio dono (colaborador não consegue), então **quem cria é o
dono do repositório**:

1. https://github.com/settings/personal-access-tokens/new
2. Nome `grafana-self-healing-dispatch`, resource owner `jairowmd`, expiração
   depois da apresentação.
3. *Repository access*: **Only select repositories** → `TM-fiap-infra-p3`.
4. *Repository permissions*: **Contents: Read and write** (Metadata read-only
   entra sozinho). Nada além disso.
5. Gerar e passar direto para o `terraform apply`:

```powershell
$env:TF_VAR_github_dispatch_token = "github_pat_..."
terraform -chdir=terraform apply
```

Não cadastre o token pela interface do Grafana: ele roda sem persistência e
perde tudo que não vem do Git a cada restart do Pod.

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

## Integração com o alerta (provisionada pelo Git)

Tudo fica em `gitops/observability/grafana/alerting/self-healing.yaml`, aplicado
pelo ArgoCD (app `grafana-config`) e carregado pelo sidecar de alertas do Grafana:

- **Contact point `self-healing-github`** (webhook): `POST` em
  `https://api.github.com/repos/jairowmd/TM-fiap-infra-p3/dispatches`, com
  `Authorization: Bearer $GITHUB_DISPATCH_TOKEN` e o payload do
  `repository_dispatch` montado com os labels `deployment` e `alertname`.
- **Regra `AuthService5xx`** (pasta *Self-Healing*): mesma consulta do painel de
  5xx do dashboard, condição `> 5`, pendente por 1 min, labels
  `deployment=auth-service` e `self_healing=true`.
- A regra aponta direto para o contact point (`notification_settings`), então a
  árvore de notification policies continua livre para PagerDuty/OpsGenie/ChatOps.
  Para o mesmo incidente também chegar no plantão, crie a rota de plantão
  casando `severity=critical` ou troque o `notification_settings` por uma
  policy com `continue: true`.

Para adicionar outro serviço ao Self-Healing, copie a regra trocando o
`job=~"(.+/)?<serviço>"` e o label `deployment`. O deployment precisa estar na
lista permitida do `rollout-restart.sh` e no RBAC.

Conferir depois do deploy:

```bash
kubectl -n observability get externalsecret grafana-self-healing      # SecretSynced
kubectl -n observability get configmap grafana-alerting-self-healing
kubectl -n observability logs deploy/kube-prometheus-stack-grafana -c grafana-sc-alerts | tail
```

No Grafana: **Alerting → Alert rules → Self-Healing → AuthService5xx** e
**Alerting → Contact points → self-healing-github** (botão *Test* dispara o
workflow de verdade, com `deployment` vazio: o runbook recusa e sai com erro 2).

## Teste de ponta a ponta (com o alerta)

1. Injetar a falha (`POST /auth/admin/chaos`, passo 1 de *Teste no EKS sem o alerta*) e gerar
   tráfego em `/auth/validate` por alguns minutos.
2. Em ~2 min a regra `AuthService5xx` passa de *Pending* para *Firing*.
3. O Grafana chama o `repository_dispatch` e o workflow **Self-Healing** aparece
   na aba Actions com evento `repository_dispatch` e alerta `AuthService5xx`.
4. O Pod é recriado, a taxa de 5xx cai e a regra volta para *Normal*.

## Evidências para o relatório

- Resumo da execução na aba Actions (o runbook escreve os Pods antes/depois).
- `kubectl get pods -w` mostrando o Pod antigo terminando e o novo subindo.
- Log do auth-service com `CHAOS:` antes do restart e sem ele depois.
