# Lifecycle da infraestrutura

## Ownership e dependências

Terraform gerencia AWS, EKS, add-ons, StorageClass `gp3`, controllers Helm e
o release `togglemaster-bootstrap`. Esse release contém somente a Application
`togglemaster-root`. ArgoCD gerencia as Applications filhas e seus workloads.
O AWS Load Balancer Controller gerencia ALBs, target groups e SGs dinâmicos.
Nenhum desses recursos dinâmicos deve ser importado para duplicar ownership.

```text
Apply:
VPC + rotas/NAT → EKS + nodes + acesso administrativo
  → Pod Identity Agent → associação EBS CSI → add-on EBS CSI → gp3
  → controllers + serviços AWS + permissões dos workloads
  → ArgoCD → bootstrap raiz → Applications → workloads/Ingress → ALB

Destroy:
bootstrap raiz (finalizer foreground)
  → Applications filhas (finalizers foreground)
  → recursos gerenciados, incluindo Ingress
  → controller conclui cleanup AWS e libera finalizer do Ingress
  → Applications e raiz desaparecem; uninstall do bootstrap termina
  → ArgoCD/controllers e recursos Kubernetes restantes
  → add-ons/nodes → EKS → rede
```

Ramos independentes podem operar em paralelo. Não é necessário remover o Load
Balancer Controller antes do ArgoCD: ele permanece disponível durante toda a
cascata. Controllers, nodes, acesso e conectividade precisam continuar saudáveis.

O provider Helm **3.3.0**, fixado no lockfile, encaminha `wait = true` para o
uninstall. Helm espera a exclusão da Application raiz; o finalizer ArgoCD
`resources-finalizer.argocd.argoproj.io` conecta essa espera à exclusão das
Applications filhas e dos recursos gerenciados. O timeout de 30 minutos é um
limite de espera por estado, não uma pausa fixa. Aumentar o timeout não corrige
falhas de IAM, controllers indisponíveis ou finalizers sem reconciliador.

Referências: [provider Helm 3.3.0](https://github.com/hashicorp/terraform-provider-helm/blob/v3.3.0/helm/resource_helm_release.go),
[Helm uninstall](https://github.com/helm/helm/blob/v3.18.0/pkg/action/uninstall.go),
[cascata ArgoCD](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/).

## Preparação no WSL

Execute na raiz do repositório, no Ubuntu/WSL, com Terraform, AWS CLI, Helm e
kubectl disponíveis:

```bash
export AWS_PROFILE=mateus-fase4
export AWS_REGION=us-east-2
export TF_VAR_aws_profile="$AWS_PROFILE"
aws sts get-caller-identity
terraform -chdir=terraform init -lockfile=readonly
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=lifecycle.tfplan
```

Confirme a conta `443670030001`. O principal retornado por STS precisa estar em
`eks_cluster_admin_principal_arns`; para uma sessão de role, configure o ARN IAM
da role, não o ARN STS da sessão. A seleção de profile é a mesma nos providers
AWS, Helm e Kubernetes. O backend S3 usa `AWS_PROFILE` separadamente.

As alterações GitOps precisam estar publicadas na branch `main` do repositório
configurado antes do teste: ArgoCD não lê os arquivos locais. Em um cluster
existente, espere a sincronização dos finalizers de todas as Applications antes
de destruir. Não use um plano de destroy antigo.

## Teste 1: criação

```bash
terraform -chdir=terraform apply lifecycle.tfplan
CLUSTER=$(terraform -chdir=terraform output -raw eks_cluster_name)
VPC=$(terraform -chdir=terraform output -raw vpc_id)
aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION" --profile "$AWS_PROFILE"
aws eks describe-cluster --name "$CLUSTER" --query cluster.status
aws eks list-nodegroups --cluster-name "$CLUSTER"
aws eks list-addons --cluster-name "$CLUSTER"
kubectl get nodes
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m
kubectl -n kube-system rollout status deployment/ebs-csi-controller --timeout=5m
kubectl -n external-secrets get deployments,pods
kubectl -n argocd get deployments,statefulsets,pods
kubectl -n argocd get applications
kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,FINALIZERS:.metadata.finalizers
kubectl -n togglemaster get deployments,pods,services,ingress,externalsecrets
kubectl -n observability get pods,pvc
kubectl get storageclass gp3 -o yaml
```

Consulte `describe-nodegroup` e `describe-addon` para cada nome listado: todos
devem estar `ACTIVE`. Aguarde Applications `Synced`/`Healthy`, Secrets prontos,
pods disponíveis e Ingress com endereço. Teste as rotas existentes dos cinco
microsserviços pelo endereço do ALB. Confirme o PVC do Loki `Bound` em `gp3`.

## Teste 2: destruição

Guarde `CLUSTER` e `VPC` antes da remoção, no mesmo terminal. Em outro terminal,
acompanhe Applications, Ingress e logs do controller enquanto disponíveis:

```bash
kubectl -n argocd get applications --watch
kubectl -n togglemaster get ingress --watch
kubectl -n kube-system logs deployment/aws-load-balancer-controller --follow
```

Execute o fluxo normal:

```bash
terraform -chdir=terraform destroy
```

O bootstrap deve aguardar a cascata enquanto ArgoCD e Load Balancer Controller
continuam disponíveis. Confirme que ALB/target groups/SGs gerenciados pelo
controller desaparecem antes de seus controllers. A StorageClass é removida
antes do EKS e das associações de acesso necessárias.

Para inspecionar AWS, use os IDs guardados:

```bash
aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC'].[LoadBalancerArn,State.Code]"
aws elbv2 describe-target-groups --query "TargetGroups[?VpcId=='$VPC'].[TargetGroupArn,TargetGroupName]"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" --query 'SecurityGroups[].[GroupId,GroupName,Tags]'
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC" --query 'NetworkInterfaces[].[NetworkInterfaceId,Description,Status,Groups]'
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC"
aws ec2 describe-vpcs --filters "Name=vpc-id,Values=$VPC"
aws eks describe-cluster --name "$CLUSTER"
terraform -chdir=terraform state list
```

Durante o teardown, ENIs de nodes/control plane e SGs do EKS ainda são esperados
até a exclusão dos respectivos recursos. Não os trate como resíduos do ALB.
Ao final, as consultas por VPC devem estar vazias, o cluster deve retornar
`ResourceNotFoundException` e o state da stack deve estar vazio. O bootstrap S3
do backend é outra stack e permanece existente.

## Limites e diagnóstico sem remover finalizers

### Applications locais corrigidas, mas GitOps remoto ainda sem finalizers

No teste de 2026-11-04, a `main` remota ainda apontava para
`05e6544b3d621a0d9b9ef6c26b9f27d03ef3f402`, cujas Applications não declaravam
os finalizers adicionados localmente. O Terraform consumiu o chart local da raiz,
mas ArgoCD continuou consumindo as Applications da branch remota. Portanto a
remoção das Applications não propagou a limpeza dos workloads como pretendido.

Foi observado após o destroy parcial: nenhuma Application, cinco Deployments e
o Ingress ainda existentes, operator External Secrets já removido, cinco
ExternalSecrets em exclusão com `externalsecrets.external-secrets.io/externalsecret-cleanup`
e CRD `externalsecrets.external-secrets.io` aguardando esses objetos. Isso explica
o timeout do uninstall. Aumentar o timeout não repõe o reconciliador ausente.

Antes de outro teste, publique os manifests corrigidos e confira os finalizers
**nos nove objetos vivos**, incluindo a raiz, antes de executar destroy. O
ambiente parcialmente destruído exige recuperar os controllers necessários e
concluir o cleanup dos workloads; reaplicar toda a stack recriaria recursos já
removidos. Uma CRD em exclusão também pode impedir reinstalar diretamente o chart
do operator, exigindo um procedimento de recuperação específico para esse estado.

O aviso de CRDs ArgoCD preservadas por `helm.sh/resource-policy: keep` é separado
do erro do External Secrets. Essas definições permanecem no cluster até sua
remoção; preservar a CRD não remove nem garante a limpeza de suas instâncias.

### Outros bloqueios

O grafo Terraform não conhece diretamente os recursos AWS criados pelos
controllers. A cadeia declarativa acima espera a reconciliação por meio dos
finalizers, mas não substitui uma auditoria AWS e não garante limpeza caso o
controller falhe, perca IAM/conectividade ou recursos sejam criados fora do GitOps.
Também pode haver atraso entre exclusão do ALB e liberação das ENIs pela AWS.

Para isolar o cleanup em uma investigação, use excepcionalmente duas fases:

```bash
terraform -chdir=terraform destroy -target=module.argocd.helm_release.bootstrap
# Verifique Applications/Ingress e as consultas AWS acima antes de continuar.
terraform -chdir=terraform destroy
```

O primeiro comando remove a raiz e inicia a cascata, preservando seus controllers.
É repetível quando o bootstrap já foi removido. Não execute `apply` entre as fases,
pois recriaria o bootstrap. Se houver resíduos, preserve os controllers e examine
eventos/logs/IAM; não avance simplesmente removendo finalizers, SGs ou ENIs.
Targeting é uma ferramenta de diagnóstico, não o fluxo habitual.

PVCs/PVs merecem inspeção separada: a política de retenção do StatefulSet/chart e
o reclaim policy do PV determinam a remoção do volume. Apagar a StorageClass não
apaga volumes existentes. Confira esses recursos antes da remoção dos nodes;
volumes retidos precisam de uma decisão explícita sobre os dados.

Não foi introduzido script imperativo de teardown: o provider em uso já espera
o uninstall, permitindo corrigir a cadeia com ownership e finalizers. Se o teste
real revelar um recurso cujo cleanup não esteja coberto por essa cadeia, registre
seu owner e o bloqueio antes de acrescentar outro mecanismo.

## Validação desta alteração

Validação executada no Ubuntu/WSL: Terraform 1.16.0, `fmt -check -recursive`,
`validate`, `helm lint` e renderização do chart de bootstrap. Foram conferidos os
finalizers da raiz e das oito Applications filhas.

O plan remoto foi comparado com um plan do código anterior (`HEAD`), usando as
mesmas variáveis e credenciais. Ambos: **86 criações, 0 alterações, 0 destruições**
e uma VPC existente sem alteração. Não foram adicionados endereços de recursos.
Entre os atributos dos recursos planejados, mudaram somente `timeout` e
`timeouts` do bootstrap; o finalizer da raiz está no template local Helm e os
das filhas serão consumidos por GitOps. Dependências alteram a ordem de execução.
Diferenças de finais de linha CRLF/LF foram desconsideradas na comparação.

O state consultado ainda contém `module.vpc.aws_vpc.this`; portanto não está
completamente vazio. Nenhum `apply` ou `destroy` foi executado na validação.
O ciclo real continua necessário para comprovar a limpeza dos recursos dinâmicos.
