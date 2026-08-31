# Módulo EKS (IAM + Amazon EKS)

Este diretório contém a infraestrutura de **IAM e Amazon EKS** do projeto ToggleMaster — responsabilidade do GX de Cloud/DevOps (IAM + EKS).

O objetivo é disponibilizar um cluster Kubernetes gerenciado, pronto para receber posteriormente o ArgoCD, os 5 microsserviços (`auth-service`, `flag-service`, `targeting-service`, `evaluation-service`, `analytics-service`) e permissões específicas por Pod via IRSA/EKS Pod Identity.

---

# 📋 Sumário

- [Arquitetura](#-arquitetura)
- [O que foi criado](#-o-que-foi-criado)
- [Estrutura do Módulo](#-estrutura-do-módulo)
- [Decisões de Design](#-decisões-de-design)
- [Variáveis](#-variáveis)
- [Outputs](#-outputs)
- [Integração com o Root do Terraform](#-integração-com-o-root-do-terraform)
- [Pré-requisitos](#-pré-requisitos)
- [Como Executar](#-como-executar)
- [Validação](#-validação)
- [Troubleshooting](#-troubleshooting)
- [Pendências / Próximos Passos](#-pendências--próximos-passos)
- [Status Atual](#-status-atual)

---

# 🏗 Arquitetura

```text
AWS
│
└── VPC (módulo vpc, JAIRO)
    │
    └── Private Subnets
        │
        ├── EKS Control Plane (gerenciado pela AWS)
        │        │
        │        └── IAM: <project>-<env>-eks-cluster-role
        │
        └── Managed Node Group (EC2 Worker Nodes)
                 │
                 └── IAM: <project>-<env>-eks-node-role
```

Fluxo de dependência entre IAM, EKS e os módulos vizinhos:

```text
modules/vpc
    │
    +-- vpc_id
    +-- private_subnet_ids
              │
              ▼
        modules/eks
              │
              ├── iam.tf     → Cluster Role, Node Role
              ├── main.tf    → EKS Cluster, Access Entries, Node Group, Add-ons
              └── outputs.tf → cluster_name, cluster_endpoint, cluster_security_group_id, ...
                          │
                          ▼
        ┌─────────────────┴─────────────────┐
        │                                    │
modules/security-groups            CI/CD, ArgoCD, kubectl
(JOAO            (usam cluster_name,
 cluster_security_group_id         cluster_endpoint,
 como application_security_group_id) cluster_certificate_authority_data)
```

---

# 🚀 O que foi criado

| Arquivo | Conteúdo |
|---|---|
| `iam.tf` | EKS Cluster Role (trust policy `eks.amazonaws.com` + `AmazonEKSClusterPolicy`) e EKS Node Role (trust policy `ec2.amazonaws.com` + `AmazonEKSWorkerNodePolicy` + `AmazonEKS_CNI_Policy` + `AmazonEC2ContainerRegistryReadOnly`) |
| `variables.tf` | Interface do módulo: naming, rede recebida da VPC, versão do Kubernetes, configuração de acesso ao endpoint, admins do cluster, configuração do Node Group, flag do metrics-server |
| `main.tf` | `aws_eks_cluster`, `aws_eks_access_entry`/`aws_eks_access_policy_association` (acesso administrativo via kubectl), `aws_eks_node_group`, add-ons (`vpc-cni`, `kube-proxy`, `coredns`, `metrics-server`) |
| `outputs.tf` | Informações expostas para outros módulos e para o time (cluster, node group, roles, SG, OIDC issuer) |

Nenhum recurso de rede (VPC/Subnet/SG de banco) foi criado aqui — tudo é recebido via variável dos módulos existentes.

---

# 📁 Estrutura do Módulo

```text
terraform/modules/eks/
├── iam.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── README.md
```

---

# 🧠 Decisões de Design

### Versão do Kubernetes

Fixada como variável (`kubernetes_version`, default `"1.34"`), não hardcoded no `main.tf`. Verificado em [docs.aws.amazon.com/eks/kubernetes-versions-standard](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html): em standard support hoje estão 1.33 (fim de suporte em 29/jul/2026), 1.34, 1.35 e 1.36 (lançada jun/2026). Optei por **1.34** por já estar madura em compatibilidade de add-ons sem estar perto do fim de vida.

### Provider AWS

O root já fixa `aws = "~> 5.0"` (`terraform/providers.tf`), resolvido em `5.100.0` no lock file — acima do mínimo (`>= 5.34`) exigido pelo bloco `access_config`/`authentication_mode` usado no cluster. Nenhuma mudança de provider foi necessária.


### EKS Access Entries (acesso via kubectl)

Com `access_config { authentication_mode = "API_AND_CONFIG_MAP" }`, a AWS **não concede mais acesso automático** a quem cria o cluster. Sem isso, o `apply` funciona mas ninguém autentica via `kubectl`. Por isso a variável `cluster_admin_principal_arns` é **obrigatória de ser preenchida** (com o ARN de quem for operar o cluster) — o módulo cria `aws_eks_access_entry` + `aws_eks_access_policy_association` (`AmazonEKSClusterAdminPolicy`) para cada ARN informado.

### Endpoint público vs privado

`endpoint_private_access` sempre `true` (nodes nunca saem da VPC para falar com a API). `endpoint_public_access` default `true`, restrito por `cluster_endpoint_public_access_cidrs` (default `0.0.0.0/0`, **recomenda-se restringir ao seu IP** em uso real) — decisão pensada para ambiente acadêmico, onde o `kubectl` roda do laptop sem VPN/bastion.

### IAM Role para os Add-ons de rede (CNI)

`AmazonEKS_CNI_Policy` foi anexada diretamente à Node Role (não via IRSA/Pod Identity). É a abordagem suportada pela AWS e suficiente para o MVP; IRSA exigiria o cluster já existir (OIDC issuer só é gerado após o `aws_eks_cluster`), o que criaria uma dependência circular na primeira aplicação. Fica registrado como melhoria futura (ver seção de pendências).

---

# ⚙️ Variáveis

| Variável | Tipo | Default | Descrição |
|---|---|---|---|
| `project_name` | `string` | — | Nome do projeto, usado em naming/tags |
| `environment` | `string` | — | Ambiente (`dev`, `staging`, `prod`) |
| `vpc_id` | `string` | — | ID da VPC (output do módulo `vpc`) |
| `private_subnet_ids` | `list(string)` | — | Subnets privadas para nodes e ENIs (mínimo 2 AZs, validado) |
| `cluster_additional_security_group_ids` | `list(string)` | `[]` | SGs extras opcionais para o control plane |
| `kubernetes_version` | `string` | `"1.34"` | Versão do control plane EKS |
| `cluster_endpoint_public_access` | `bool` | `true` | Habilita endpoint público da API |
| `cluster_endpoint_public_access_cidrs` | `list(string)` | `["0.0.0.0/0"]` | CIDRs liberados para o endpoint público |
| `cluster_admin_principal_arns` | `list(string)` | `[]` | ARNs IAM com acesso admin ao cluster (**obrigatório preencher**) |
| `node_group_config` | `object({...})` | `t3.medium`, `ON_DEMAND`, `2/1/3`, `20GB` | Configuração de instância e escala do Node Group |
| `enable_metrics_server` | `bool` | `true` | Liga/desliga o add-on `metrics-server` |

---

# 📤 Outputs

| Output | Consumidor | Uso |
|---|---|---|
| `cluster_name` | você, CI/CD, ArgoCD | `aws eks update-kubeconfig` |
| `cluster_arn` | auditoria | referência do recurso |
| `cluster_endpoint` | kubectl, ArgoCD, providers Terraform kubernetes/helm | acesso à API |
| `cluster_certificate_authority_data` | kubectl, ArgoCD | TLS |
| `cluster_security_group_id` | `application_security_group_id` no módulo `security-groups` |
| `cluster_oidc_issuer_url` | futuro (IRSA) | ainda não consumido nesta fase |
| `node_group_name` | observabilidade | identificação |
| `node_role_arn` | políticas futuras | anexar permissões adicionais aos nodes |
| `cluster_role_arn` | auditoria | referência do recurso |

---

# 🔗 Integração com o Root do Terraform

Arquivos do diretório `terraform/` (raiz) que foram **alterados** para conectar este módulo:

| Arquivo | Alteração |
|---|---|
| `main.tf` | Adicionado `module "eks"`, recebendo `vpc_id`/`private_subnet_ids` de `module.vpc` |
| `variables.tf` | Adicionadas `eks_kubernetes_version` e `eks_cluster_admin_principal_arns` |
| `outputs.tf` | Adicionados `eks_cluster_name`, `eks_cluster_endpoint`, `eks_cluster_security_group_id`, `eks_node_role_arn` |
| `terraform.tfvars.example` | Adicionado exemplo de `eks_kubernetes_version` e `eks_cluster_admin_principal_arns` |

Nenhum arquivo de `modules/vpc` ou `modules/security-groups` foi modificado — apenas seus outputs já existentes foram referenciados.

```hcl
module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version            = var.eks_kubernetes_version
  cluster_admin_principal_arns  = var.eks_cluster_admin_principal_arns
}
```

---

# 📋 Pré-requisitos

- Módulo `vpc` aplicado (fornece `vpc_id` e `private_subnet_ids`).
- Terraform `>= 1.5.0`, provider `hashicorp/aws ~> 5.0` (já configurado no root).
- AWS CLI configurado com permissões para criar recursos IAM/EKS/EC2.
- Preencher `eks_cluster_admin_principal_arns` no `terraform.tfvars` com o ARN de quem vai operar o cluster (`aws sts get-caller-identity --query Arn --output text`).

---

# ▶️ Como Executar

```powershell
cd terraform
terraform fmt -recursive
terraform init -upgrade
terraform validate
terraform plan
terraform apply
```

Depois do `apply` (cluster leva ~10-15 min para `ACTIVE`):

```powershell
aws eks update-kubeconfig --name <eks_cluster_name> --region us-east-1
kubectl get nodes
kubectl get pods -A
```

---

# 🔎 Validação

Resultado esperado:

- `terraform plan` sem erros, mostrando cluster + node group + add-ons + IAM roles a serem criados.
- `kubectl get nodes` → 2 nodes em `Ready`.
- `kubectl get pods -A` → pods de `kube-system` (`aws-node`, `kube-proxy`, `coredns`, `metrics-server`) em `Running`.

---

# 🛠 Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `AccessDenied` no `apply` | credenciais AWS sem permissão IAM/EKS | conferir `aws sts get-caller-identity` e as policies do usuário/role |
| Erro de `iam:PassRole` | quem roda o Terraform não pode passar a role para EKS/EC2 | adicionar `iam:PassRole` restrito aos ARNs das duas roles criadas |
| `kubectl` retorna `Unauthorized`/`forbidden` | `cluster_admin_principal_arns` vazio ou ARN incorreto | confirmar ARN com `aws sts get-caller-identity` e reaplicar |
| Nodes não entram no cluster | Node Role sem as 3 policies, ou subnets incorretas | conferir `iam.tf` e se `private_subnet_ids` têm rota para NAT Gateway |
| `ErrImagePull` do ECR | falta `AmazonEC2ContainerRegistryReadOnly`, ou imagem em outra região | conferir policy attachment e região do ECR |
| Security Groups bloqueando RDS/Redis | usar `eks_cluster_security_group_id` como `application_security_group_id` |
| `kubectl` não conecta | endpoint público desabilitado ou IP fora do CIDR liberado | conferir `cluster_endpoint_public_access_cidrs` |

---

# 🔜 Pendências / Próximos Passos

- **OIDC Provider (IRSA)**: criar `aws_iam_openid_connect_provider` apontando para `cluster_oidc_issuer_url` — só é possível após o cluster existir; fica como passo isolado quando alguém for configurar permissões por Service Account (ArgoCD ou os 5 microsserviços).
- Migrar `AmazonEKS_CNI_Policy` da Node Role para uma role dedicada via IRSA/EKS Pod Identity.
- Avaliar `EKS Pod Identity` para cada microsserviço (acesso a Secrets Manager, DynamoDB, SQS) quando os workloads forem definidos.
- Preparar namespace/RBAC para o ArgoCD (fora do escopo deste módulo).

---

# 📌 Status Atual

```text
[✓] EKS Cluster Role (IAM)
[✓] EKS Node Role (IAM)
[✓] EKS Cluster (control plane)
[✓] EKS Access Entries (acesso via kubectl)
[✓] Managed Node Group
[✓] Add-on vpc-cni
[✓] Add-on kube-proxy
[✓] Add-on coredns
[✓] Add-on metrics-server
[✓] Outputs para integração com outros módulos
[✓] Integração em terraform/main.tf, variables.tf, outputs.tf
[✓] terraform plan/apply real (30 to add, 0 to change, 0 to destroy)
[✓] kubectl get nodes — 2 nodes Ready
[✓] kubectl get pods -A — aws-node, kube-proxy, coredns, metrics-server Running
[ ] OIDC Provider / IRSA
```
