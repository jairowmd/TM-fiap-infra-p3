# Prometheus + Grafana

Métricas, visualização e o dashboard customizado do ToggleMaster (Fase 4,
requisito 1). Tudo é entregue pelo ArgoCD a partir deste repositório.

## Arquitetura

```text
microsserviços ──OTLP (4317/4318)──► OTel Collector ──┬─ métricas ─► Prometheus  (/api/v1/otlp)
                                     (daemonset)      ├─ logs ─────► Loki        (/otlp)
                                                      └─ traces ───► APM
kubelet/cAdvisor, kube-state-metrics, node-exporter ──scrape──► Prometheus

Grafana ──► Prometheus (uid: prometheus) + Loki (uid: loki)
        └─► dashboard "ToggleMaster — Saúde do Ecossistema" (pasta ToggleMaster)
```

- **Métricas de infraestrutura**: o Prometheus faz scrape do kubelet/cAdvisor
  (CPU e memória dos containers), kube-state-metrics (pods, deployments, HPA)
  e node-exporter (CPU e memória dos nodes).
- **Métricas das aplicações**: os serviços não são "raspados". Eles enviam
  métricas OTLP ao OTel Collector, que as encaminha ao receptor OTLP nativo do
  Prometheus. O Collector é o único ponto de roteamento, como o desafio pede.

## Arquivos

| Arquivo | Função |
| --- | --- |
| `gitops/applications/observability/kube-prometheus-stack.yml` | Application ArgoCD do chart `kube-prometheus-stack` 92.18.0 (Prometheus Operator, Prometheus, Grafana, kube-state-metrics, node-exporter). |
| `gitops/observability/kube-prometheus-stack/values.yaml` | Configuração: receptor OTLP, retenção 7d em gp3 10Gi, componentes de control plane do EKS desligados, Alertmanager desligado (alertas ficam no Grafana), datasource Loki. |
| `gitops/applications/observability/grafana-config.yml` | Application ArgoCD (kustomize) com os dashboards e a credencial do Grafana. |
| `gitops/observability/grafana/dashboards/*.json` | Dashboards versionados. Cada JSON vira um ConfigMap com o label `grafana_dashboard: "1"`, importado pelo sidecar do Grafana. |
| `gitops/observability/grafana/external-secret.yaml` | Senha do admin vinda do Secrets Manager (`GRAFANA_ADMIN_PASSWORD`, gerada pelo Terraform). |
| `gitops/observability/otel-collector/values.yaml` | Pipeline `metrics` exporta para o Prometheus (`otlphttp/prometheus`). |

## Acesso ao Grafana

O Grafana não é exposto na internet; o acesso é por port-forward:

```bash
kubectl -n observability get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  (usuário: admin)
```

Prometheus (consultas e targets):

```bash
kubectl -n observability port-forward svc/prometheus-operated 9090:9090
# http://localhost:9090/targets
```

## Dashboard "ToggleMaster — Saúde do Ecossistema"

Variáveis: `Namespace` (padrão `togglemaster`), `Microsserviço` (multi-seleção)
e `Buscar nos logs` (regex). Anotações marcam restarts de pods e rollouts, o que
deixa visível no gráfico o momento em que o self-healing agiu.

| Linha | Painéis | Fonte |
| --- | --- | --- |
| Visão geral | Nodes Ready, CPU e memória do cluster, pods Running, pods com problema, restarts (1h) | kube-state-metrics, node-exporter |
| Recursos do cluster | CPU/memória por node, CPU/memória por microsserviço, réplicas disponíveis x HPA | node-exporter, cAdvisor, kube-state-metrics |
| Tráfego HTTP | req/s, % de 5xx (faixa vermelha em 5%), latência p50/p95, 5xx do auth-service, throughput total | métricas OTel via Collector |
| Logs | volume de logs, logs de erro, logs em tempo real | Loki |

O JSON é a fonte de verdade: alterações feitas pela UI não são salvas
(`allowUiUpdates: false`). Para mudar o dashboard, edite na UI, use
**Share → Export → Save to file**, substitua o JSON no repositório e faça merge
na `main`.

## Contrato de instrumentação (para quem instrumenta os serviços)

Os painéis de tráfego HTTP dependem de três pontos:

1. **`OTEL_SERVICE_NAME` igual ao nome do deployment** (`auth-service`,
   `flag-service`, `targeting-service`, `evaluation-service`,
   `analytics-service`). O Prometheus transforma `service.name` no label `job`.
2. **Convenções semânticas HTTP estáveis**: a métrica esperada é
   `http.server.request.duration` (segundos), que vira
   `http_server_request_duration_seconds_{count,bucket,sum}` com o label
   `http_response_status_code`.
   - Go (`otelhttp`): versões atuais já emitem essa métrica.
   - Python (Flask): defina `OTEL_SEMCONV_STABILITY_OPT_IN=http`; sem isso a
     instrumentação emite a métrica antiga `http.server.duration`.
3. **Exportar métricas via OTLP** para o Collector:
   `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc.cluster.local:4318`
   e `OTEL_METRICS_EXPORTER=otlp`.

Verificação rápida no Prometheus:

```promql
sum by (job) (rate(http_server_request_duration_seconds_count[5m]))
```

## Consulta para o alerta de 5xx

Expressão usada no stat "auth-service — erros 5xx" e sugerida para a regra de
alerta do Grafana (condição `> 5`, pendente por 1–2 min, label
`deployment=auth-service`, exigido pelo workflow de self-healing):

```promql
100 * sum(rate(http_server_request_duration_seconds_count{job=~"(.+/)?auth-service",http_response_status_code=~"5.."}[5m]))
  / sum(rate(http_server_request_duration_seconds_count{job=~"(.+/)?auth-service"}[5m]))
```

## Roteiro para o vídeo

1. `kubectl -n argocd get applications` → `kube-prometheus-stack`,
   `grafana-config`, `loki` e `otel-collector` em `Synced/Healthy`.
2. `kubectl -n observability get pods,pvc` → Prometheus e Loki com PVC `Bound`.
3. Grafana → pasta **ToggleMaster** → dashboard. Gerar tráfego no ALB e mostrar
   req/s subindo; mostrar CPU/memória do cluster.
4. **Explore → Loki**: `{k8s_namespace_name="togglemaster", k8s_container_name="auth-service"}`.
5. Prometheus → **Status → Targets** e a consulta acima, explicando que as
   métricas de aplicação chegaram via OTel Collector (OTLP), não por scrape.

## Verificação após o deploy

```bash
kubectl -n argocd get application kube-prometheus-stack grafana-config
kubectl -n observability get pods
kubectl -n observability get externalsecret grafana-admin   # SecretSynced
kubectl -n observability get configmap -l grafana_dashboard=1
kubectl -n observability logs daemonset/otel-collector | grep -i -E "error|prometheus"
```

Se o Grafana ficar em `CreateContainerConfigError`, o Secret `grafana-admin`
ainda não existe: confira o ExternalSecret e se o `terraform apply` já gravou
`GRAFANA_ADMIN_PASSWORD` no Secrets Manager.
