# TM FIAP - Infraestrutura Terraform

Este repositório contém a infraestrutura como código (**Infrastructure as Code - IaC**) do projeto **Tech Challenge - Fase 3 da FIAP**.

A infraestrutura é provisionada utilizando **Terraform** e **AWS**, seguindo uma estrutura modular para facilitar a manutenção, reutilização e evolução do ambiente.

O objetivo desta primeira etapa é disponibilizar uma **Infraestrutura Core**, responsável pela base de rede e segurança necessária para os próximos componentes da aplicação.

---

# 📋 Sumário

- [Arquitetura](#-arquitetura)
- [Infraestrutura Implementada](#-infraestrutura-implementada)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Módulo VPC](#-módulo-vpc)
- [Módulo Security Groups](#-módulo-security-groups)
- [Regras de Segurança](#-regras-de-segurança)
- [Terraform Backend](#-terraform-backend)
- [Variáveis](#-variáveis)
- [Outputs](#-outputs)
- [Pré-requisitos](#-pré-requisitos)
- [Como Executar](#-como-executar)
- [Validação da Infraestrutura](#-validação-da-infraestrutura)
- [Fluxo de Desenvolvimento](#-fluxo-de-desenvolvimento)
- [Testes Realizados](#-testes-realizados)
- [Próximas Etapas](#-próximas-etapas)

---

# 🏗 Arquitetura

Atualmente, o projeto provisiona a camada base da infraestrutura AWS.

```text
AWS
│
└── VPC
    │
    ├── Internet Gateway
    │
    ├── NAT Gateway
    │
    ├── Public Subnets
    │   │
    │   ├── Public Subnet 1
    │   └── Public Subnet 2
    │
    ├── Private Subnets
    │   │
    │   ├── Private Subnet 1
    │   └── Private Subnet 2
    │
    ├── Route Tables
    │   │
    │   ├── Public Route Table
    │   └── Private Route Table
    │
    └── Security Groups
        │
        ├── Database Security Group
        │   └── Regras para banco de dados
        │
        └── Redis Security Group
            └── Regras para Redis
```

A infraestrutura foi organizada em módulos Terraform.

```text
Terraform
│
├── VPC Module
│   ├── VPC
│   ├── Subnets Públicas
│   ├── Subnets Privadas
│   ├── Internet Gateway
│   ├── Elastic IP
│   ├── NAT Gateway
│   ├── Route Tables
│   └── Route Table Associations
│
├── Security Groups Module
│   ├── Database Security Group
│   ├── Regras de acesso ao Database
│   ├── Redis Security Group
│   └── Regras de acesso ao Redis
│
└── Terraform Backend
    └── S3 Bucket para armazenamento do Terraform State
```

---

# 🚀 Infraestrutura Implementada

Atualmente, a infraestrutura possui os seguintes componentes.

| Recurso | Status | Descrição |
|---|---|---|
| VPC | ✅ | Rede principal da infraestrutura |
| Public Subnets | ✅ | Subnets para recursos que necessitam acesso público |
| Private Subnets | ✅ | Subnets para recursos internos |
| Internet Gateway | ✅ | Permite comunicação entre a VPC e a Internet |
| Elastic IP | ✅ | IP público utilizado pelo NAT Gateway |
| NAT Gateway | ✅ | Permite saída para Internet a partir das subnets privadas |
| Public Route Table | ✅ | Tabela de rotas das subnets públicas |
| Private Route Table | ✅ | Tabela de rotas das subnets privadas |
| Database Security Group | ✅ | Grupo de segurança para banco de dados |
| Redis Security Group | ✅ | Grupo de segurança para Redis |
| Regras Database | ✅ | Regras de comunicação definidas no módulo |
| Regras Redis | ✅ | Regras de comunicação definidas no módulo |
| S3 Terraform Backend | ✅ | Armazenamento remoto do Terraform State |

---

# 📁 Estrutura do Projeto

```text
TM-fiap-infra-p3/
│
├── README.md
│
├── bootstrap/
│   │
│   ├── README.md
│   │
│   └── s3/
│       └── ...
│
└── terraform/
    │
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    ├── versions.tf
    ├── terraform.tfvars
    │
    └── modules/
        │
        ├── vpc/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        │
        └── security-groups/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

A estrutura foi dividida para separar as responsabilidades da infraestrutura.

---

# 🌐 Módulo VPC

Localização:

```text
terraform/modules/vpc
```

Este módulo é responsável pela criação de toda a infraestrutura de rede.

## Recursos provisionados

### VPC

A VPC representa a rede principal onde os recursos da aplicação serão executados.

CIDR utilizado:

```text
10.0.0.0/16
```

---

### Public Subnets

Foram criadas duas subnets públicas distribuídas entre diferentes Availability Zones.

```text
10.0.1.0/24
10.0.2.0/24
```

As subnets públicas possuem:

```text
map_public_ip_on_launch = true
```

Isso permite que recursos criados nessas subnets possam receber IP público quando aplicável.

---

### Private Subnets

Foram criadas duas subnets privadas.

```text
10.0.11.0/24
10.0.12.0/24
```

As subnets privadas não atribuem IP público automaticamente.

```text
map_public_ip_on_launch = false
```

Essas subnets são destinadas a recursos internos da infraestrutura.

---

### Internet Gateway

O Internet Gateway é conectado à VPC para permitir comunicação entre recursos públicos e a Internet.

Fluxo:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Route Table
   │
   ▼
Public Subnets
```

---

### NAT Gateway

O NAT Gateway permite que recursos localizados nas subnets privadas tenham acesso de saída para a Internet.

Isso é importante, por exemplo, quando recursos privados precisam:

- baixar atualizações;
- acessar APIs externas;
- instalar dependências;
- acessar serviços externos.

Fluxo:

```text
Private Subnet
      │
      ▼
Private Route Table
      │
      ▼
NAT Gateway
      │
      ▼
Internet Gateway
      │
      ▼
Internet
```

O NAT Gateway utiliza um Elastic IP.

---

### Route Tables

A infraestrutura possui duas tabelas de rotas principais.

#### Public Route Table

Responsável pelas subnets públicas.

Possui rota para:

```text
0.0.0.0/0
```

Direcionada para:

```text
Internet Gateway
```

Fluxo:

```text
Public Subnet
     │
     ▼
Public Route Table
     │
     ▼
Internet Gateway
     │
     ▼
Internet
```

---

#### Private Route Table

Responsável pelas subnets privadas.

Possui rota para:

```text
0.0.0.0/0
```

Direcionada para:

```text
NAT Gateway
```

Fluxo:

```text
Private Subnet
     │
     ▼
Private Route Table
     │
     ▼
NAT Gateway
     │
     ▼
Internet Gateway
     │
     ▼
Internet
```

---

# 🔐 Módulo Security Groups

Localização:

```text
terraform/modules/security-groups
```

Este módulo é responsável pela criação dos grupos de segurança da camada de dados.

Atualmente são provisionados:

```text
Database Security Group
Redis Security Group
```

---

## Database Security Group

Nome gerado dinamicamente:

```text
${project}-${environment}-database-sg
```

Exemplo:

```text
tm-fiap-p3-dev-database-sg
```

Esse Security Group será utilizado pelos recursos de banco de dados do projeto.

A definição das regras de acesso é realizada através do módulo, permitindo controlar quais recursos poderão se comunicar com o banco.

---

## Redis Security Group

Nome gerado dinamicamente:

```text
${project}-${environment}-redis-sg
```

Exemplo:

```text
tm-fiap-p3-dev-redis-sg
```

Esse Security Group será utilizado pelos recursos Redis da infraestrutura.

Assim como no Database Security Group, as regras são definidas de forma controlada para limitar a comunicação apenas aos recursos necessários.

---

# 🛡 Regras de Segurança

A criação dos Security Groups foi separada da definição da infraestrutura de rede.

Isso permite que a arquitetura mantenha responsabilidades claras:

```text
VPC Module
    │
    └── Responsável pela infraestrutura de rede
```

```text
Security Groups Module
    │
    └── Responsável pelas regras de comunicação
```

A relação entre os módulos ocorre através do ID da VPC.

No arquivo principal:

```hcl
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id = module.vpc.vpc_id
}
```

Dessa forma, o Terraform entende que os Security Groups dependem da VPC.

O fluxo de dependência é:

```text
VPC
 │
 ▼
VPC ID
 │
 ▼
Security Groups
 │
 ├── Database SG
 │
 └── Redis SG
```

---

# 💾 Terraform Backend

Localização:

```text
bootstrap/
└── s3/
```

O projeto possui uma estrutura separada para o provisionamento dos recursos necessários para armazenar o Terraform State remotamente.

```text
bootstrap
   │
   └── s3
        │
        └── Terraform State Backend
```

O objetivo é separar a infraestrutura responsável pelo gerenciamento do estado da infraestrutura principal.

## Por que separar o Bootstrap?

O backend precisa existir antes que a infraestrutura principal possa utilizá-lo.

Por isso, o fluxo é:

```text
1. Criar infraestrutura de Bootstrap
            │
            ▼
2. Criar S3 Backend
            │
            ▼
3. Configurar Terraform Backend
            │
            ▼
4. Provisionar Infraestrutura Principal
```

Essa separação evita que o Terraform tente utilizar um backend que ainda não existe.

---

# ⚙️ Variáveis

As configurações do ambiente são centralizadas através de variáveis Terraform.

Exemplos:

```hcl
project_name = "tm-fiap-p3"

environment = "dev"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]
```

Essa abordagem permite reutilizar os módulos em diferentes ambientes.

Exemplo:

```text
dev
staging
prod
```

---

# 📤 Outputs

Os módulos expõem informações necessárias para comunicação entre os componentes.

Exemplo:

```text
VPC Module
    │
    └── vpc_id
          │
          ▼
Security Groups Module
```

O `vpc_id` é utilizado pelo módulo de Security Groups para criar os recursos dentro da VPC correta.

Após a execução do Terraform, também é possível consultar os outputs:

```powershell
terraform output
```

---

# 📋 Pré-requisitos

Antes de executar o projeto, é necessário possuir:

- Terraform instalado;
- AWS CLI instalado;
- credenciais AWS configuradas;
- permissões adequadas na conta AWS;
- Git instalado.

Verificar a instalação do Terraform:

```powershell
terraform version
```

Verificar a AWS CLI:

```powershell
aws --version
```

Verificar a identidade AWS utilizada:

```powershell
aws sts get-caller-identity
```

---

# ▶️ Como Executar

Entre no diretório principal do Terraform:

```powershell
cd terraform
```

Inicialize o projeto:

```powershell
terraform init
```

Formate os arquivos Terraform:

```powershell
terraform fmt -recursive
```

Valide a configuração:

```powershell
terraform validate
```

Visualize as alterações planejadas:

```powershell
terraform plan
```

Aplique a infraestrutura:

```powershell
terraform apply
```

Confirme digitando:

```text
yes
```

---

# 🔎 Validação da Infraestrutura

Após o `terraform apply`, é recomendado executar novamente:

```powershell
terraform plan
```

O resultado esperado é:

```text
No changes. Your infrastructure matches the configuration.
```

Isso significa que:

```text
Código Terraform
        =
Terraform State
        =
Infraestrutura AWS
```

Ou seja, a infraestrutura provisionada está de acordo com a configuração declarada no código.

---

# 🧪 Testes Realizados

A infraestrutura foi testada utilizando o ciclo completo do Terraform.

## Validação

```powershell
terraform validate
```

A configuração foi validada sem erros.

---

## Planejamento

```powershell
terraform plan
```

O Terraform identificou corretamente os recursos que deveriam ser provisionados.

---

## Provisionamento

```powershell
terraform apply
```

A infraestrutura foi criada com sucesso.

Durante o teste completo foram provisionados:

```text
16 resources added
0 changed
0 destroyed
```

Os recursos incluíram:

```text
VPC
2 Public Subnets
2 Private Subnets
Internet Gateway
Elastic IP
NAT Gateway
2 Route Tables
4 Route Table Associations
Database Security Group
Redis Security Group
```

---

## Teste de Recriação da Infraestrutura

Também foi realizado um teste importante de Infrastructure as Code.

A infraestrutura foi removida e posteriormente recriada utilizando apenas a configuração Terraform.

Após a recriação, foram provisionados novamente os recursos esperados.

Exemplo:

```text
Plan: 16 to add, 0 to change, 0 to destroy.
```

Após o `apply`:

```text
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.
```

Em seguida, uma nova validação foi executada:

```powershell
terraform plan
```

Resultado:

```text
No changes. Your infrastructure matches the configuration.
```

Esse teste demonstrou que a infraestrutura pode ser recriada de forma consistente a partir do código Terraform.

---

# 🌿 Fluxo de Desenvolvimento

O projeto utiliza branches para separar alterações.

Exemplo de fluxo:

```text
main
 │
 ├── feature/vpc
 │
 ├── feature/security-groups
 │
 └── feature/documentation
```

Fluxo recomendado:

```text
Criar Branch
     │
     ▼
Desenvolver alteração
     │
     ▼
terraform fmt
     │
     ▼
terraform validate
     │
     ▼
terraform plan
     │
     ▼
terraform apply
     │
     ▼
terraform plan
     │
     ▼
git add
     │
     ▼
git commit
     │
     ▼
git push
     │
     ▼
Pull Request
     │
     ▼
Code Review
     │
     ▼
Merge
```

Exemplo de criação de uma nova feature:

```powershell
git checkout main
```

```powershell
git pull origin main
```

```powershell
git checkout -b feature/nova-feature
```

Após concluir:

```powershell
git add .
```

```powershell
git commit -m "feat: descrição da alteração"
```

```powershell
git push -u origin feature/nova-feature
```

Depois disso, deve ser criada uma Pull Request para revisão e integração ao projeto.

---

# 🏷 Padrão de Commits

Sugestão de padrão:

```text
feat: nova funcionalidade
```

Exemplo:

```text
feat(security): add database and redis security groups
```

Para documentação:

```text
docs: update infrastructure documentation
```

Para correções:

```text
fix: correct security group rule
```

Para alterações de Terraform:

```text
infra: update terraform network configuration
```

---

# 🔄 Fluxo de Dependências

A infraestrutura possui dependências entre seus componentes.

```text
VPC
 │
 ├── Internet Gateway
 │
 ├── Public Subnets
 │
 └── Private Subnets
       │
       ▼
   Route Tables
       │
       ▼
   NAT Gateway
```

Os Security Groups dependem da VPC:

```text
VPC
 │
 ▼
module.vpc.vpc_id
 │
 ▼
Security Groups
 │
 ├── Database SG
 │
 └── Redis SG
```

O Terraform identifica automaticamente essas dependências através das referências entre recursos e módulos.

---

# 🔜 Próximas Etapas

A Infraestrutura Core já possui os principais componentes de rede e segurança necessários para receber os próximos recursos.

Possíveis próximos módulos:

```text
terraform/modules/
│
├── vpc/
├── security-groups/
│
├── rds/
├── elasticache/
├── ecr/
├── eks/
└── monitoring/
```

A sequência definitiva deve ser alinhada com a arquitetura e a divisão de responsabilidades do grupo.

Possíveis dependências:

```text
VPC
 │
 ├── Security Groups
 │
 ├── RDS
 │
 ├── ElastiCache
 │
 └── EKS
        │
        ▼
   Aplicações
```

---

# 👥 Colaboração

Para os integrantes que irão utilizar esta infraestrutura:

1. Atualizar o repositório:

```powershell
git checkout main
git pull origin main
```

2. Criar uma branch para a nova funcionalidade:

```powershell
git checkout -b feature/nome-da-feature
```

3. Desenvolver a alteração.

4. Executar obrigatoriamente:

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

5. Validar cuidadosamente o plano antes de aplicar qualquer alteração.

6. Enviar a alteração para o repositório:

```powershell
git add .
git commit -m "feat: descrição da alteração"
git push -u origin feature/nome-da-feature
```

7. Criar uma Pull Request para revisão.

---

# ⚠️ Boas Práticas

Antes de executar alterações na infraestrutura:

```text
Sempre executar terraform plan.
```

Antes de realizar um commit:

```text
Sempre executar terraform fmt e terraform validate.
```

Após aplicar alterações:

```text
Executar novamente terraform plan.
```

O objetivo é garantir que:

```text
Código
   ↓
Terraform State
   ↓
AWS
```

permaneçam sincronizados.

---

# 📌 Status Atual

Infraestrutura Core:

```text
[✓] VPC
[✓] Public Subnets
[✓] Private Subnets
[✓] Internet Gateway
[✓] Elastic IP
[✓] NAT Gateway
[✓] Public Route Table
[✓] Private Route Table
[✓] Route Table Associations
[✓] Database Security Group
[✓] Redis Security Group
[✓] Regras de acesso para Database
[✓] Regras de acesso para Redis
[✓] S3 Terraform Backend
[✓] Terraform validate
[✓] Terraform apply
[✓] Teste de recriação da infraestrutura
[✓] Terraform plan sem alterações
```

A base da infraestrutura está preparada para a evolução dos próximos componentes do projeto.\n# Teste CI / DevSecOps
\n# Trigger CI/CD
