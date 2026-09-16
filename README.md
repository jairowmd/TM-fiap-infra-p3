# TM FIAP - Infraestrutura Terraform

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-blue.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Provider-orange.svg)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34+-green.svg)](https://kubernetes.io/)

Repositório de **Infraestrutura como Código (IaC)** do projeto **Tech Challenge - Fase 3 da FIAP** utilizando **Terraform** e **AWS**.

Esta infraestrutura provisiona uma base completa para a execução de **5 microsserviços** (auth, flag, targeting, evaluation, analytics) em um cluster **Amazon EKS** gerenciado com **GitOps** via **ArgoCD**.

---

## 📋 Sumário

- [Visão Geral](#-visão-geral)
- [Arquitetura](#-arquitetura)
- [Componentes Implementados](#-componentes-implementados)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Módulos Terraform](#-módulos-terraform)
- [Variáveis de Configuração](#-variáveis-de-configuração)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação e Configuração](#-instalação-e-configuração)
- [Como Executar](#-como-executar)
- [Outputs e Integração](#-outputs-e-integração)
- [Fluxo de Desenvolvimento](#-fluxo-de-desenvolvimento)
- [Boas Práticas](#-boas-práticas)
- [Troubleshooting](#-troubleshooting)
- [Próximas Etapas](#-próximas-etapas)

---

## 🎯 Visão Geral

A infraestrutura foi construída seguindo princípios de **modularidade**, **escalabilidade** e **segurança**. Ela provisiona:

- **Rede (VPC)**: VPC com subnets públicas e privadas distribuídas em múltiplas Availability Zones
- **Kubernetes (EKS)**: Cluster Kubernetes gerenciado com nodes em subnets privadas
- **Dados**: 3 instâncias PostgreSQL (auth, flag, targeting), Redis (ElastiCache), DynamoDB e SQS
- **Gerenciamento**: ArgoCD para GitOps, External Secrets para gestão de credenciais
- **Ingresso**: AWS Load Balancer Controller para ALB integrado ao EKS
- **Registros**: ECR repositories para os 5 microsserviços

O objetivo é fornecer uma base pronta para deploy de aplicações containerizadas com alta disponibilidade e segurança.

---

## 🏗 Arquitetura

### Visão Geral da Infraestrutura

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS Account                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      VPC (10.0.0.0/16)                   │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │                                                            │   │
│  │  Public Subnets (IGW)  │  Private Subnets (NAT Gateway)  │   │
│  │  ┌──────────────────┐  │  ┌──────────────────────────┐   │   │
│  │  │ 10.0.1.0/24      │  │  │ 10.0.11.0/24 (EKS)      │   │   │
│  │  │ 10.0.2.0/24      │  │  │ 10.0.12.0/24 (EKS)      │   │   │
│  │  └──────────────────┘  │  │ 10.0.21.0/24 (RDS/Cache)│   │   │
│  │                         │  │ 10.0.22.0/24 (RDS/Cache)│   │   │
│  │                         │  └──────────────────────────┘   │   │
│  │                                                            │   │
│  │  ┌──────────────────────────────────────────────────┐    │   │
│  │  │     Amazon EKS Cluster                           │    │   │
│  │  │  ┌─────────────────────────────────────────────┐ │    │   │
│  │  │  │  Control Plane (Managed)                   │ │    │   │
│  │  │  └─────────────────────────────────────────────┘ │    │   │
│  │  │  ┌─────────────────────────────────────────────┐ │    │   │
│  │  │  │  Managed Node Group (2 nodes)              │ │    │   │
│  │  │  │  ├── ArgoCD                                │ │    │   │
│  │  │  │  ├── External Secrets                      │ │    │   │
│  │  │  │  ├── AWS Load Balancer Controller          │ │    │   │
│  │  │  │  ├── 5 Microsserviços                      │ │    │   │
│  │  │  │  │   ├── auth-service                      │ │    │   │
│  │  │  │  │   ├── flag-service                      │ │    │   │
│  │  │  │  │   ├── targeting-service                 │ │    │   │
│  │  │  │  │   ├── evaluation-service                │ │    │   │
│  │  │  │  │   └── analytics-service                 │ │    │   │
│  │  │  │  └── Add-ons (vpc-cni, kube-proxy, etc)   │ │    │   │
│  │  │  └─────────────────────────────────────────────┘ │    │   │
│  │  └──────────────────────────────────────────────────┘    │   │
│  │                                                            │   │
│  │  ┌─────────────────────────────────────────────────────┐  │   │
│  │  │         Data Layer (Private Subnets)               │  │   │
│  │  ├─────────────────────────────────────────────────────┤  │   │
│  │  │                                                     │  │   │
│  │  │  RDS                                               │  │   │
│  │  │  ├── auth-db (postgres)                            │  │   │
│  │  │  ├── flag-db (postgres)                            │  │   │
│  │  │  └── targeting-db (postgres)                       │  │   │
│  │  │                                                     │  │   │
│  │  │  ElastiCache                                       │  │   │
│  │  │  └── Redis (evaluation-service)                    │  │   │
│  │  │                                                     │  │   │
│  │  │  DynamoDB                                          │  │   │
│  │  │  └── analytics-table (analytics-service)           │  │   │
│  │  │                                                     │  │   │
│  │  │  SQS                                               │  │   │
│  │  │  └── evaluation-analytics-queue                    │  │   │
│  │  │                                                     │  │   │
│  │  └─────────────────────────────────────────────────────┘  │   │
│  │                                                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │    Security & Management                                 │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  • Security Groups (Database, Redis, EKS)                │   │
│  │  • AWS Secrets Manager (credenciais)                     │   │
│  │  • IAM Roles (EKS, Nodes, External Secrets, ALB)         │   │
│  │  • OIDC Provider (para IRSA)                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Fluxo de Dados

```
Internet / Clientes
         │
         ▼
AWS Application Load Balancer (ALB)
         │
         ▼
EKS Cluster (Kubernetes Service)
         │
    ┌────┴────┐
    │          │
    ▼          ▼
Microsserviços
    │
    └──────────────────────────────────────┐
                                            │
        ┌───────────────────┬───────────────┼───────────────┐
        │                   │               │               │
        ▼                   ▼               ▼               ▼
   PostgreSQL           Redis          DynamoDB           SQS
   (3 DBs)            (Cache)           (analytics)    (messaging)
```

---

## ✅ Componentes Implementados

| Componente | Tipo | Status | Descrição |
|---|---|---|---|
| **VPC** | Network | ✅ | Rede principal com CIDR 10.0.0.0/16 |
| **Public Subnets** | Network | ✅ | 2 subnets em AZs diferentes (10.0.1.0/24, 10.0.2.0/24) |
| **Private Subnets** | Network | ✅ | 4 subnets para EKS, RDS, ElastiCache |
| **Internet Gateway** | Network | ✅ | Acesso à internet para subnets públicas |
| **NAT Gateway** | Network | ✅ | Saída de dados para subnets privadas |
| **Route Tables** | Network | ✅ | Públicas e privadas configuradas |
| **EKS Cluster** | Compute | ✅ | Kubernetes 1.34 com 2 nodes gerenciados |
| **EKS Add-ons** | Compute | ✅ | vpc-cni, kube-proxy, coredns, metrics-server |
| **EKS OIDC** | Security | ✅ | Provider para IRSA |
| **Security Groups** | Security | ✅ | Database, Redis, EKS |
| **RDS PostgreSQL** | Data | ✅ | 3 instâncias (auth, flag, targeting) |
| **ElastiCache Redis** | Data | ✅ | 1 cluster para evaluation-service |
| **DynamoDB** | Data | ✅ | Tabela para analytics-service |
| **SQS** | Messaging | ✅ | Fila para evaluation ↔ analytics |
| **ECR** | Registry | ✅ | 5 repositórios (auth, flag, targeting, evaluation, analytics) |
| **AWS Secrets Manager** | Secrets | ✅ | Armazenamento centralizado de credenciais |
| **External Secrets** | Secrets | ✅ | Sincronização com Kubernetes |
| **ArgoCD** | GitOps | ✅ | Deploy automático via Git |
| **AWS Load Balancer Controller** | Ingress | ✅ | ALB integrado ao EKS |
| **IAM Roles & Policies** | Security | ✅ | IRSA para microsserviços e controllers |

---

## 📁 Estrutura do Projeto

```
TM-fiap-infra-p3/
│
├── README.md
├── .gitignore
├── .github/
│   └── workflows/
│       ├── terraform-validate.yml
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
│
├── bootstrap/
│   ├── README.md
│   └── s3/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── terraform/
    ├── main.tf                 # Definição dos módulos
    ├── variables.tf            # Variáveis de entrada
    ├── outputs.tf              # Outputs expostos
    ├── providers.tf            # Configuração de providers
    ├── versions.tf             # Versões de providers
    ├── terraform.tfvars        # Valores das variáveis
    │
    └── modules/
        │
        ├── vpc/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── eks/
        │   ├── iam.tf
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── security-groups/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── rds/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── elasticache/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── dynamodb/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── sqs/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── secrets/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── external-secrets/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── argocd/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        ├── aws-load-balancer-controller/
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── README.md
        │
        └── ecr/
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            └── README.md
```

---

## 🧩 Módulos Terraform

### 1. **VPC Module**
Infraestrutura de rede base.

**Recursos criados:**
- VPC com CIDR 10.0.0.0/16
- 2 Public Subnets (10.0.1.0/24, 10.0.2.0/24)
- 4 Private Subnets para EKS, RDS e ElastiCache
- Internet Gateway
- NAT Gateway com Elastic IP
- Public e Private Route Tables
- Route Table Associations

**Outputs:**
- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`

---

### 2. **EKS Module**
Cluster Kubernetes gerenciado com controle total.

**Recursos criados:**
- IAM Role para EKS Cluster
- IAM Role para EKS Nodes
- Amazon EKS Cluster (control plane)
- Managed Node Group (2 nodes em Private Subnets)
- EKS Access Entries para acesso administrativo
- Add-ons: vpc-cni, kube-proxy, coredns, metrics-server
- OIDC Provider para IRSA

**Outputs:**
- `cluster_name`
- `cluster_endpoint`
- `cluster_arn`
- `cluster_security_group_id`
- `node_role_arn`
- `oidc_provider_arn`
- `cluster_oidc_issuer_url`

**Documentação:** Ver [`terraform/modules/eks/README.md`](terraform/modules/eks/README.md)

---

### 3. **Security Groups Module**
Controle de acesso entre recursos.

**Grupos criados:**
- **Database Security Group**: Acesso aos bancos PostgreSQL
- **Redis Security Group**: Acesso ao ElastiCache Redis

**Regras:**
- EKS cluster pode acessar Database e Redis
- Database e Redis comunicam apenas entre si e com EKS

---

### 4. **RDS Module**
3 instâncias PostgreSQL independentes.

**Recursos criados:**
- Database subnet group
- 3 RDS instances: auth-db, flag-db, targeting-db
- Parameter groups para cada database
- Multi-AZ enabled para alta disponibilidade

**Outputs:**
- `endpoints`: Mapa com endpoints de cada database
- `database_names`: Nomes dos databases
- `port`: Porta PostgreSQL

---

### 5. **ElastiCache Module**
Redis para cache distribuído.

**Recursos criados:**
- Cache subnet group
- Redis cluster node
- Parameter group customizado

**Outputs:**
- `endpoint`: Endpoint do Redis
- `port`: Porta Redis

---

### 6. **DynamoDB Module**
Armazenamento NoSQL para analytics.

**Recursos criados:**
- Tabela DynamoDB com billing on-demand
- GSIs (Global Secondary Indexes) conforme necessário

**Outputs:**
- `table_name`
- `table_arn`

---

### 7. **SQS Module**
Fila de mensagens para comunicação assíncrona.

**Recursos criados:**
- Standard Queue
- Dead Letter Queue (DLQ)

**Outputs:**
- `queue_url`
- `queue_arn`

---

### 8. **Secrets Module**
Armazenamento centralizado de credenciais.

**Recurso criado:**
- AWS Secrets Manager Secret com todos os endpoints e credenciais

**Valores armazenados:**
- Database URLs (auth, flag, targeting)
- Redis URL
- SQS URL
- DynamoDB table name
- Master key para auth-service
- Região AWS

---

### 9. **External Secrets Module**
Sincronização de secrets com Kubernetes.

**Recursos criados:**
- Helm deployment do External Secrets Operator
- SecretStore conectado ao AWS Secrets Manager
- ExternalSecret para cada microsserviço

**Integração:**
- Usa IRSA para acesso seguro ao Secrets Manager
- Cria Kubernetes Secrets automaticamente

---

### 10. **ArgoCD Module**
GitOps para deploy automático.

**Recursos criados:**
- Helm deployment do ArgoCD
- Namespace argocd
- ApplicationSets para microsserviços

**Integração:**
- Deploye automático via repositório Git
- Sincronização contínua com desired state

---

### 11. **AWS Load Balancer Controller Module**
Ingress controller para ALB.

**Recursos criados:**
- Helm deployment do AWS Load Balancer Controller
- IAM Role para IRSA
- Policy para criar ALBs

**Integração:**
- Cria ALBs automaticamente a partir de Kubernetes Ingresses
- Integração nativa com EKS

---

### 12. **ECR Module**
Registros de container para cada microsserviço.

**Recursos criados:**
- 5 repositórios ECR:
  - `tm-fiap-p3-dev-auth`
  - `tm-fiap-p3-dev-flag`
  - `tm-fiap-p3-dev-targeting`
  - `tm-fiap-p3-dev-evaluation`
  - `tm-fiap-p3-dev-analytics`

**Configuração:**
- Lifecycle policy: retain últimas 10 imagens
- Force delete enabled para deleção de recursos

---

## ⚙️ Variáveis de Configuração

### Variáveis Obrigatórias

```hcl
# Região AWS
aws_region = "us-east-1"

# Projeto
project_name = "tm-fiap-p3"
environment  = "dev"

# Rede
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.21.0/24", "10.0.22.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# EKS
eks_cluster_admin_principal_arns = ["arn:aws:iam::ACCOUNT_ID:user/USERNAME"]

# Database
db_password = "SetPasswordHere123!"  # Via TF_VAR_db_password

# Helm Charts
external_secrets_chart_version                    = "0.12.0"
aws_load_balancer_controller_chart_version = "1.14.1"
```

### Variáveis Opcionais

```hcl
# Database
db_username = "dbadmin"  # Default

# EKS
eks_kubernetes_version = "1.34"  # Default

# AWS Load Balancer Controller
aws_load_balancer_controller_chart_version = "1.14.1"  # Default
```

---

## 📋 Pré-requisitos

### Software Obrigatório

- **Terraform** ≥ 1.0
  ```bash
  terraform version
  ```

- **AWS CLI** ≥ 2.0
  ```bash
  aws --version
  ```

- **kubectl** ≥ 1.28
  ```bash
  kubectl version --client
  ```

- **Helm** ≥ 3.0
  ```bash
  helm version
  ```

- **Git**
  ```bash
  git --version
  ```

### Credenciais e Permissões

1. **AWS Credentials** configuradas:
   ```bash
   aws configure
   # ou
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   ```

2. **Verificar identidade AWS:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Permissões necessárias:**
   - EC2 (VPC, Subnets, Security Groups)
   - EKS (Cluster, Node Groups)
   - RDS (Databases)
   - ElastiCache (Redis)
   - DynamoDB
   - SQS
   - Secrets Manager
   - IAM (Roles, Policies)
   - ECR (Repositories)

### S3 Terraform Backend

1. **Criar S3 bucket para Terraform State:**
   ```bash
   cd bootstrap/s3
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configurar backend em `terraform/providers.tf`:**
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "tm-fiap-p3-terraform-state"
       key            = "prod/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "terraform-locks"
     }
   }
   ```

---

## 🚀 Instalação e Configuração

### 1. Clonar o Repositório

```bash
git clone https://github.com/jairowmd/TM-fiap-infra-p3.git
cd TM-fiap-infra-p3
```

### 2. Configurar AWS Credentials

```bash
aws configure
# ou
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### 3. Configurar terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Editar com seus valores
nano terraform/terraform.tfvars
```

### 4. Configurar DB Password

```bash
export TF_VAR_db_password="YourSecurePassword123!"
```

### 5. Inicializar Terraform

```bash
cd terraform
terraform init
```

---

## ▶️ Como Executar

### Step 1: Validar Configuração

```bash
cd terraform

# Formatar código
terraform fmt -recursive

# Validar sintaxe
terraform validate

# Planejar mudanças
terraform plan
```

### Step 2: Revisar Plano

Sempre revise o plano antes de aplicar:

```bash
terraform plan | tee plan.txt
```

Verifique:
- Número de recursos a criar/modificar/destruir
- Nomes corretos dos recursos
- Valores das variáveis
- Dependências

### Step 3: Aplicar Infraestrutura

```bash
terraform apply

# Confirmar digitando 'yes'
```

**Tempo estimado:** 25-35 minutos (incluindo EKS e RDS)

### Step 4: Verificar Aplicação

```bash
# Obter outputs
terraform output

# Configurar kubectl
aws eks update-kubeconfig \
  --region us-east-1 \
  --name tm-fiap-p3-dev-eks

# Verificar cluster
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

---

## 📤 Outputs e Integração

Após `terraform apply`, acesse os outputs:

```bash
terraform output
```

### Principais Outputs:

```
# VPC
vpc_id                  = "vpc-xxxxxxxxx"
public_subnet_ids       = ["subnet-xxx", "subnet-xxx"]
private_subnet_ids      = ["subnet-xxx", "subnet-xxx", ...]

# EKS
eks_cluster_name        = "tm-fiap-p3-dev-eks"
eks_cluster_endpoint    = "https://xxx.us-east-1.eks.amazonaws.com"
eks_cluster_arn         = "arn:aws:eks:..."
eks_oidc_provider_arn   = "arn:aws:iam::..."
eks_oidc_issuer_url     = "https://oidc.eks...."

# RDS
rds_endpoints = {
  auth      = "auth-db.xxxxx.us-east-1.rds.amazonaws.com:5432"
  flag      = "flag-db.xxxxx.us-east-1.rds.amazonaws.com:5432"
  targeting = "targeting-db.xxxxx.us-east-1.rds.amazonaws.com:5432"
}

# Cache
redis_endpoint = "xxx.xxxxx.cache.amazonaws.com"
redis_port     = 6379

# Messaging
sqs_queue_url  = "https://sqs.us-east-1.amazonaws.com/..."

# Registry
ecr_repositories = {
  auth       = "xxx.dkr.ecr.us-east-1.amazonaws.com/tm-fiap-p3-dev-auth"
  flag       = "xxx.dkr.ecr.us-east-1.amazonaws.com/tm-fiap-p3-dev-flag"
  targeting  = "xxx.dkr.ecr.us-east-1.amazonaws.com/tm-fiap-p3-dev-targeting"
  evaluation = "xxx.dkr.ecr.us-east-1.amazonaws.com/tm-fiap-p3-dev-evaluation"
  analytics  = "xxx.dkr.ecr.us-east-1.amazonaws.com/tm-fiap-p3-dev-analytics"
}
```

### Usar Outputs em Scripts

```bash
# Exportar para variáveis de ambiente
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint)

# Usar em scripts
echo $CLUSTER_NAME
```

---

## 🧪 Fluxo de Desenvolvimento

### Fluxo de Feature

```bash
# 1. Atualizar main
git checkout main
git pull origin main

# 2. Criar feature branch
git checkout -b feature/nova-feature

# 3. Fazer alterações
# Editar arquivos Terraform

# 4. Validar
cd terraform
terraform fmt -recursive
terraform validate
terraform plan

# 5. Revisar plano cuidadosamente
# (Nunca confie em plano sem revisar!)

# 6. Aplicar (se correto)
terraform apply

# 7. Validar aplicação
terraform plan
# Deve retornar: "No changes"

# 8. Commit e push
git add .
git commit -m "feat: descrição clara da alteração"
git push -u origin feature/nova-feature

# 9. Abrir Pull Request
# Aguardar revisão
```

### Padrão de Commits

```bash
feat(module): nova funcionalidade
fix(module): corrige bug
docs: atualiza documentação
infra(module): alteração de configuração
refactor: reorganiza código
test: adiciona testes

# Exemplos:
feat(eks): add OIDC provider for IRSA
fix(security-groups): allow RDS access from EKS
docs: update deployment guide
infra(rds): increase storage allocation
```

---

## ⚠️ Boas Práticas

### Sempre Executar Antes de Commit

```bash
terraform fmt -recursive   # Formatar
terraform validate         # Validar sintaxe
terraform plan             # Planejar
# Revisar output cuidadosamente!
```

### Antes de Aplicar

```bash
# Fazer backup do state (se remote)
terraform state pull > terraform.tfstate.backup

# Executar plan novamente
terraform plan

# Ler cuidadosamente o que será modificado
# Se tiver dúvidas, NÃO aplique!
```

### Após Aplicar

```bash
# Verificar estado
terraform plan
# Esperado: "No changes. Your infrastructure matches the configuration."

# Validar na AWS
aws ec2 describe-vpcs
aws eks describe-cluster --name CLUSTER_NAME
```

### Gestão de Secrets

- ✅ Usar `TF_VAR_db_password` via variável de ambiente
- ✅ Armazenar credenciais no AWS Secrets Manager
- ❌ NÃO commitar `terraform.tfvars` com senhas
- ❌ NÃO expostar credenciais em logs

### Backup do State

```bash
# Backup local
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Verificar S3 versionamento
aws s3api get-bucket-versioning --bucket tm-fiap-p3-terraform-state
```

---

## 🔍 Troubleshooting

### 1. "Error acquiring the state lock"

**Problema:** Outro plano/apply em execução

**Solução:**
```bash
terraform force-unlock LOCK_ID
```

### 2. "InvalidUserID.NotFound: The user ID does not exist"

**Problema:** ARN de usuário incorreto

**Solução:**
```bash
# Verificar ARN correto
aws sts get-caller-identity
# Atualizar terraform.tfvars com ARN correto
```

### 3. "AccessDenied: User is not authorized to perform: eks:DescribeCluster"

**Problema:** Falta de permissões AWS

**Solução:**
```bash
# Adicionar policy ao usuário/role
aws iam attach-user-policy \
  --user-name USERNAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFullAccess
```

### 4. "Error: error reading S3 Bucket Versioning"

**Problema:** S3 backend não inicializado

**Solução:**
```bash
cd bootstrap/s3
terraform apply
```

### 5. Nodes não aparecem no cluster

**Problema:** Security group mal configurado ou node role incorreta

**Solução:**
```bash
# Verificar nodes
kubectl get nodes -o wide

# Checar logs
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=CLUSTER_NAME"

# Verificar security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*eks*"
```

### 6. Pods em estado `Pending`

**Problema:** Recursos insuficientes ou network policy

**Solução:**
```bash
# Verificar recursos
kubectl describe node NODE_NAME

# Verificar logs do pod
kubectl describe pod POD_NAME -n NAMESPACE

# Aumentar node group
# Editar módulo eks/main.tf e aumentar desired_size
```

### 7. RDS não está acessível

**Problema:** Security group ou subnet incorretos

**Solução:**
```bash
# Verificar security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx

# Testar conectividade do pod
kubectl run -it --rm debug \
  --image=postgres:15 \
  --restart=Never \
  -- psql -h ENDPOINT -U USERNAME -d DATABASE
```

---

## 🔜 Próximas Etapas

### Curto Prazo (Próxima Sprint)

- [ ] Implementar OIDC Provider / IRSA (já pronto, aguardando finalização)
- [ ] Configurar namespaces e RBAC por microsserviço
- [ ] Testar permissões de pod
- [ ] Documentar IRSA setup completo

### Médio Prazo

- [ ] Implementar monitoring (CloudWatch, Prometheus)
- [ ] Setup de logging (CloudWatch Logs, ELK)
- [ ] Autoscaling de nós (Cluster Autoscaler)
- [ ] Autoscaling de pods (HPA)
- [ ] Backup automático (RDS snapshots, DynamoDB backups)

### Longo Prazo

- [ ] Multi-region setup
- [ ] Disaster recovery procedures
- [ ] Blue-green deployment strategy
- [ ] Cost optimization
- [ ] Compliance e segurança avançada

### Roadmap de Módulos

```
✅ vpc
✅ security-groups
✅ eks
✅ rds
✅ elasticache
✅ dynamodb
✅ sqs
✅ secrets
✅ external-secrets
✅ argocd
✅ aws-load-balancer-controller
✅ ecr

🔄 Próximos:
  □ monitoring (CloudWatch, Prometheus, Grafana)
  □ logging (ELK, CloudWatch Logs)
  □ autoscaling (Cluster Autoscaler, HPA)
  □ backup (AWS Backup, Velero)
  □ networking (Service Mesh - Istio/Linkerd)
```

---

## 👥 Colaboração

### Para Contribuidores

1. **Clonar repositório:**
   ```bash
   git clone https://github.com/jairowmd/TM-fiap-infra-p3.git
   cd TM-fiap-infra-p3
   ```

2. **Criar feature branch:**
   ```bash
   git checkout -b feature/seu-nome-feature
   ```

3. **Antes de commitar:**
   ```bash
   cd terraform
   terraform fmt -recursive
   terraform validate
   terraform plan
   # Revisar cuidadosamente!
   ```

4. **Commit com padrão:**
   ```bash
   git add .
   git commit -m "feat: descrição clara e concisa"
   git push -u origin feature/seu-nome-feature
   ```

5. **Abrir Pull Request com:**
   - Título descritivo
   - Descrição do que muda
   - Screenshots (se aplicável)
   - Checklist de testes

---

## 📚 Referências

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)

---

## 📝 Status Atual

### Infraestrutura Core

- [x] VPC com subnets públicas e privadas
- [x] Internet Gateway e NAT Gateway
- [x] Route tables configuradas
- [x] Security Groups (Database, Redis, EKS)
- [x] S3 Terraform Backend
- [x] Terraform validate e apply

### Compute

- [x] EKS Cluster (Kubernetes 1.34)
- [x] Managed Node Group (2 nodes)
- [x] EKS Add-ons (vpc-cni, kube-proxy, coredns, metrics-server)
- [x] EKS Access Entries
- [x] OIDC Provider para IRSA

### Data Layer

- [x] RDS PostgreSQL (3 instâncias: auth, flag, targeting)
- [x] ElastiCache Redis (1 cluster)
- [x] DynamoDB (tabela analytics)
- [x] SQS (fila evaluation-analytics)

### Gerenciamento

- [x] AWS Secrets Manager
- [x] External Secrets Operator
- [x] ArgoCD
- [x] AWS Load Balancer Controller

### Registry

- [x] ECR (5 repositórios)

### Testing

- [x] terraform validate ✅
- [x] terraform plan ✅
- [x] terraform apply ✅
- [x] Recriação de infraestrutura ✅
- [x] Teste de idempotência ✅
- [x] Verificação de nodes Kubernetes ✅
- [x] Verificação de pods e add-ons ✅

---

## 📞 Suporte

Para dúvidas ou problemas:

1. Verificar [Troubleshooting](#-troubleshooting)
2. Consultar documentação dos módulos em `terraform/modules/*/README.md`
3. Abrir issue no repositório
4. Contatar time de infraestrutura

---

**Última atualização:** 2026-01-15  
**Versão:** 3.0  
**Mantido por:** Time de Infraestrutura FIAP
