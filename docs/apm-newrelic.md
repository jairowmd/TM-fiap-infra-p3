# APM + Instrumentação + Tracing (New Relic)

Responsável: Guilherme — Tech Challenge Fase 4.

## Arquitetura

Os 5 microsserviços são instrumentados com **OpenTelemetry** (padrão aberto, sem
código específico do New Relic) e enviam traces e métricas via OTLP/HTTP para o
**OTel Collector**, que distribui para cada backend:

```
auth / flag / targeting / evaluation / analytics
                    │  OTLP/HTTP :4318
                    ▼
   otel-collector.observability.svc (DaemonSet)
     traces           → memory_limiter → k8sattributes → batch              → New Relic
     metrics          → k8sattributes → memory_limiter → batch              → Prometheus (João)
     metrics/newrelic → k8sattributes → memory_limiter → cumulativetodelta → batch → New Relic
     logs             → k8sattributes → memory_limiter → batch              → Loki (Mateus)
```

As métricas vão para o Prometheus e para o New Relic em pipelines separadas: a
conversão para delta (formato preferido pelo New Relic) não afeta o Prometheus.

Fluxo de uma avaliação de flag (um único trace distribuído):

```
evaluation-service  GET /evaluate
 ├─ redis GET                           (cache)
 ├─ GET flag-service /flags/{nome}      ── flag-service ── GET auth-service /validate ── PostgreSQL
 ├─ GET targeting-service /rules/{nome} ── targeting-service ── GET auth-service /validate ── PostgreSQL
 ├─ redis SET
 └─ sqs send  (traceparent nos atributos da mensagem)
        └─ analytics-service  sqs process → DynamoDB PutItem, SQS DeleteMessage
```

O cache do Redis dura 30s. Dentro desse intervalo o trace mostra só
evaluation → Redis → SQS → analytics; depois de 30s (ou com outra flag) o trace
passa também por flag, targeting e auth.

## O que foi instrumentado

| Serviço | Linguagem | Como |
| --- | --- | --- |
| auth | Go | SDK OTel (`telemetry.go`), `otelhttp` no servidor, `otelsql` nas queries do PostgreSQL |
| evaluation | Go | SDK OTel, `otelhttp` no servidor e no cliente HTTP, hook de tracing no Redis (`redis_tracing.go`), span PRODUCER no envio ao SQS com propagação do trace |
| flag | Python | Auto-instrumentação (`opentelemetry-instrument`): Flask, requests, psycopg2 |
| targeting | Python | Auto-instrumentação: Flask, requests, psycopg2 |
| analytics | Python | Auto-instrumentação (Flask, botocore) + span CONSUMER que continua o trace a partir da mensagem SQS |

Detalhes:

- `/health` é ignorado (as probes do Kubernetes não viram traces).
- Nos serviços Python os logs ganham `trace_id`/`span_id` (`OTEL_PYTHON_LOG_CORRELATION`), o que permite cruzar log no Loki com trace no New Relic.
- Os serviços Go fazem shutdown gracioso: ao receber SIGTERM enviam os spans pendentes antes de sair.
- A falha injetada do Self-Healing (`POST /admin/chaos` no auth) aparece no New Relic como erros 500 no `auth-service`, o que serve para o alerta "5xx do auth > 5%".
- Configuração por variáveis `OTEL_*` nos deployments e no ConfigMap `togglemaster-config`.

## Como ativar

### 1. Pegar a license key no New Relic

New Relic → avatar → **API Keys** → copiar a chave do tipo **INGEST - LICENSE**
(não é a "User key"). Se a conta for da região EU, trocar o endpoint em
`gitops/observability/otel-collector/values.yaml` para `https://otlp.eu01.nr-data.net`.

### 2. Criar a secret na AWS (Terraform)

`terraform/observability-secrets.tf` cria a secret `tm-fiap-p4/dev/observability`
e `terraform/main.tf` dá permissão de leitura ao External Secrets:

```bash
cd terraform
terraform plan    # deve mostrar: 1 secret nova + update na policy do external-secrets
terraform apply
```

### 3. Gravar a license key (fica fora do Git e do state)

```bash
aws secretsmanager put-secret-value --region us-east-2 \
  --secret-id tm-fiap-p4/dev/observability \
  --secret-string '{"NEW_RELIC_LICENSE_KEY":"<SUA_LICENSE_KEY>"}'
```

PowerShell (as aspas do JSON precisam de escape):

```powershell
aws secretsmanager put-secret-value --region us-east-2 `
  --secret-id tm-fiap-p4/dev/observability `
  --secret-string '{\"NEW_RELIC_LICENSE_KEY\":\"<SUA_LICENSE_KEY>\"}'
```

### 4. Chave de API do evaluation-service (`SERVICE_API_KEY`)

O evaluation-service chama flag e targeting com `Authorization: Bearer $SERVICE_API_KEY`,
mas essa variável não estava configurada no cluster: sem ela, toda avaliação sem
cache retorna 502. Para gerar a chave e criar a secret:

```bash
ALB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
MASTER_KEY=$(kubectl get secret auth-secret -n togglemaster -o jsonpath='{.data.MASTER_KEY}' | base64 -d)

# Gera uma chave de API no auth-service
curl -s -X POST "http://$ALB/auth/admin/keys" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"evaluation-service"}'
# → copie o campo "key" da resposta

kubectl create secret generic evaluation-service-api-key -n togglemaster \
  --from-literal=SERVICE_API_KEY=<KEY_GERADA>
kubectl rollout restart deployment/evaluation-service -n togglemaster
```

### 5. Deploy

Commit + push na `main`: o CI gera as imagens novas e atualiza as tags; o ArgoCD
sincroniza os deployments, o ConfigMap e o Collector.

Verificação:

```bash
kubectl get externalsecret newrelic-license -n observability   # STATUS: SecretSynced
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50
# Erros 403 no exporter otlphttp/newrelic = license key errada ou região errada
```

## Gerar tráfego e validar

Pelo ALB, os paths têm prefixo por serviço (o Ingress remove o prefixo):
`/flags/flags`, `/targeting/rules`, `/evaluate/evaluate`.

```bash
KEY=<KEY_GERADA_NO_PASSO_4>

# Cria uma flag e uma regra de 50%
curl -s -X POST "http://$ALB/flags/flags" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"nova-home","description":"Teste APM","is_enabled":true}'

curl -s -X POST "http://$ALB/targeting/rules" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"flag_name":"nova-home","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}'

# Avaliações (a cada ~35s o cache expira e o trace passa por todos os serviços)
for i in $(seq 1 200); do
  curl -s "http://$ALB/evaluate/evaluate?user_id=user-$i&flag_name=nova-home"; echo
  sleep 1
done
```

## Evidências (prints)

1. **Service Map**: New Relic → *APM & Services* → `evaluation-service` → *Service map*.
   Devem aparecer os 5 serviços + Redis, PostgreSQL e SQS/DynamoDB.
2. **Trace distribuído**: *APM & Services* → `evaluation-service` → *Distributed tracing* →
   abrir um trace de `GET /evaluate` com 5 entidades (pegar um de cache miss).
3. Lista de serviços em *APM & Services* (filtro "OpenTelemetry") mostrando os 5.

Consultas NRQL úteis (*Query your data*):

```sql
-- Spans por serviço nos últimos 30 min
SELECT count(*) FROM Span FACET service.name SINCE 30 minutes ago

-- Traces que passaram por mais serviços
SELECT uniqueCount(service.name) AS servicos FROM Span
FACET trace.id SINCE 30 minutes ago LIMIT 10

-- Latência p95 do /evaluate
SELECT percentile(duration.ms, 95) FROM Span
WHERE service.name = 'evaluation-service' AND span.kind = 'server' TIMESERIES
```
