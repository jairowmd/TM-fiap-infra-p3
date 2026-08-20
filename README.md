# TM-FIAP-Infra-P3

# 🚀 FIAP Tech Challenge – Fase 3 | Infraestrutura como Código (IaC)

Este repositório contém o código de **Infraestrutura como Código (IaC)** do projeto **FIAP Tech Challenge – Fase 3**, utilizando **Terraform** para o provisionamento dos recursos na **AWS**.

A arquitetura segue uma estrutura modular e descentralizada para garantir reusabilidade, facilitar a manutenção e permitir o trabalho em equipe sem conflitos de estado.

---

## 📋 Infraestrutura Atual (Core)

A base da infraestrutura provisionada é composta pelos seguintes componentes:

```text
Terraform
│
├── VPC
│   ├── Public Subnets
│   ├── Private Subnets
│   ├── Internet Gateway
│   ├── NAT Gateway
│   ├── Route Tables
│   └── Route Table Associations
│
├── Security Groups
│   ├── Database Security Group
│   └── Redis Security Group
│
└── S3 Terraform Backend
    └── Remote State

```

---

## 🏗️ Arquitetura de Rede

Atualmente, o Terraform provisiona a infraestrutura de rede base (Core) na AWS:

```text
                           Internet
                              │
                              ▼
                     Internet Gateway
                              │
                    ┌─────────┴─────────┐
                    │       VPC         │
                    │   10.0.0.0/16     │
                    │                   │
                    │  Public Subnets   │
                    │                   │
                    │ ┌───────────────┐ │
                    │ │ 10.0.1.0/24  │ │
                    │ │ us-east-1a   │ │
                    │ └───────────────┘ │
                    │                   │
                    │ ┌───────────────┐ │
                    │ │ 10.0.2.0/24  │ │
                    │ │ us-east-1b   │ │
                    │ └───────────────┘ │
                    │         │         │
                    │     NAT Gateway   │
                    │         │         │
                    │  Private Subnets  │
                    │                   │
                    │ ┌───────────────┐ │
                    │ │ 10.0.11.0/24 │ │
                    │ │ us-east-1a   │ │
                    │ └───────────────┘ │
                    │                   │
                    │ ┌───────────────┐ │
                    │ │ 10.0.12.0/24 │ │
                    │ │ us-east-1b   │ │
                    │ └───────────────┘ │
                    │                   │
                    └───────────────────┘

```

---

## 📁 Estrutura do Projeto

```text
TM-fiap-infra-p3/
│
├── bootstrap/
│   └── s3/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── terraform.tfvars
│
├── terraform/
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars
│   │
│   └── modules/
│       │
│       ├── vpc/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       │
│       └── security-groups/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── README.md

```

---

## 🚀 Bootstrap – Terraform Backend

Antes de criar a infraestrutura principal, um bucket S3 separado é provisionado no diretório `bootstrap/s3/` para armazenar o arquivo de estado (`terraform.tfstate`) remotamente.

Essa separação é fundamental pois o Terraform precisa do bucket já existente para inicializar o backend remoto na aplicação principal.

### Recursos do Bootstrap

* **S3 Bucket**: Armazenamento do Remote State.
* **Block Public Access**: Configuração de segurança para proibir o acesso público.

---

## 🌐 Detalhamento dos Módulos

### 1. Módulo VPC (`terraform/modules/vpc`)

Responsável pelo provisionamento do ambiente de rede:

* **VPC CIDR**: `10.0.0.0/16`
* **Subnets Públicas**:
* `10.0.1.0/24` (`us-east-1a`)
* `10.0.2.0/24` (`us-east-1b`)


* **Subnets Privadas**:
* `10.0.11.0/24` (`us-east-1a`)
* `10.0.12.0/24` (`us-east-1b`)


* **Gateways**: Internet Gateway (tráfego público) e NAT Gateway (saída de tráfego das subnets privadas).
* **Tabelas de Rota**: Separação e associação adequada entre rotas públicas e privadas.

### 2. Módulo Security Groups (`terraform/modules/security-groups`)

Responsável pelas regras de firewall dos serviços de dados:

* **Database Security Group**: `tm-fiap-p3-dev-database-sg`
* **Redis Security Group**: `tm-fiap-p3-dev-redis-sg`

---

## ⚙️ Pré-requisitos e Execução

### Pré-requisitos

* **Terraform** instalado (`v1.0+`)
* **AWS CLI** configurado com credenciais válidas (`aws sts get-caller-identity`)

### Passo a Passo

1. **Acessar o diretório principal**:
```bash
cd terraform

```


2. **Inicializar o Terraform**:
```bash
terraform init

```


3. **Validar e Formatar**:
```bash
terraform fmt -recursive
terraform validate

```


4. **Visualizar o Plano de Execução**:
```bash
terraform plan

```


5. **Aplicar a Infraestrutura**:
```bash
terraform apply

```



---

## 📊 Status Atual da Infraestrutura

| Componente | Status |
| --- | --- |
| S3 Backend (Bootstrap) | ✅ Criado |
| Terraform Remote State | ✅ Configurado |
| VPC & Subnets | ✅ Criadas |
| Internet & NAT Gateways | ✅ Criados |
| Route Tables | ✅ Criadas |
| Database & Redis Security Groups | ✅ Criados |
| RDS PostgreSQL | ⏳ Próxima etapa |
| ElastiCache (Redis) | ⏳ Próxima etapa |
| EKS Cluster & Node Groups | ⏳ Próximas etapas |

---

## 👥 Guia para os Próximos Integrantes

Os novos recursos (RDS, Redis, EKS) **não devem recriar a VPC ou Subnets**. Eles devem reutilizar a infraestrutura Core existente através dos `outputs` exportados pelo módulo `vpc`.

```text
module.vpc
     │
     ├── vpc_id
     ├── public_subnet_ids
     └── private_subnet_ids
              │
              ▼
      Próximos Módulos
      ┌───────┼────────┐
      ▼       ▼        ▼
     RDS    Redis     EKS

```

Antes de abrir Pull Requests com novas funcionalidades, certifique-se de rodar os comandos de validação (`terraform fmt`, `terraform validate` e `terraform plan`).

A infraestrutura foi provisionada, destruída e recriada com sucesso como teste de consistência do código. O teste final com terraform plan retornou No changes, confirmando que o estado da infraestrutura está sincronizado com a configuração Terraform.