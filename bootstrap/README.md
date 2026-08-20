# Bootstrap - Terraform S3 Backend


Este diretório contém a infraestrutura inicial (**bootstrap**) necessária para criar o bucket Amazon S3 utilizado como backend remoto do Terraform.


O objetivo é armazenar o arquivo de estado (`terraform.tfstate`) de forma centralizada na AWS.


---



## 📋 Objetivo


Antes de utilizar um backend remoto, o Terraform precisa que o recurso onde o state será armazenado já exista.


Por isso, a criação do bucket S3 é separada da infraestrutura principal.


Fluxo:


```text
Bootstrap
    │
    ▼
Criar S3 Bucket
    │
    ▼
Armazenar Terraform State
    │
    ▼
Infraestrutura Principal

Após a criação do bucket, a infraestrutura localizada no diretório terraform/ pode utilizar esse bucket como backend remoto.

📁 Estrutura
bootstrap/
└── s3/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    ├── terraform.tfvars
    └── terraform.tfvars.example
Arquivos
Arquivo	Descrição
main.tf	Criação do bucket S3 e configurações de segurança
variables.tf	Declaração das variáveis utilizadas no bootstrap
outputs.tf	Outputs gerados após a criação dos recursos
providers.tf	Configuração do provider AWS e Terraform
terraform.tfvars	Valores das variáveis do ambiente
terraform.tfvars.example	Exemplo de configuração das variáveis
☁️ Recursos criados

Este bootstrap cria os recursos necessários para armazenar o Terraform State remotamente.

AWS
│
└── S3 Bucket
    │
    ├── Terraform State
    │
    └── Public Access Block
S3 Bucket

O bucket é criado utilizando o padrão:

<project_name>-<environment>-terraform-state

Exemplo:

tm-fiap-p3-dev-terraform-state

O bucket possui as tags:

Name        = <project_name>-<environment>-terraform-state
Project     = <project_name>
Environment = <environment>
ManagedBy   = Terraform
Purpose     = Terraform State
🔒 Segurança

O bucket possui bloqueio de acesso público.

As seguintes configurações são aplicadas:

block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true

O objetivo é impedir que o bucket utilizado para armazenar o Terraform State fique acessível publicamente.

🔄 Por que o Bootstrap é separado?

Existe uma dependência inicial conhecida como bootstrap problem.

A infraestrutura principal precisa de um backend para armazenar o state:

Terraform Principal
       │
       ▼
Precisa do S3 Backend

Porém, inicialmente o próprio bucket S3 ainda não existe.

Por isso:

1. Executar Bootstrap
        │
        ▼
2. Criar S3 Bucket
        │
        ▼
3. Configurar Backend Remoto
        │
        ▼
4. Executar Infraestrutura Principal

Dessa forma, o bucket é criado primeiro e depois passa a ser utilizado pela infraestrutura principal.

⚙️ Pré-requisitos

Antes de executar o bootstrap, é necessário ter instalado:

Terraform
AWS CLI
Credenciais AWS configuradas

Verifique o Terraform:

terraform --version

Verifique a AWS CLI:

aws --version

Verifique as credenciais configuradas:

aws sts get-caller-identity
🚀 Como executar

Entre no diretório do bootstrap:

cd bootstrap/s3
1. Inicializar o Terraform
terraform init

Esse comando irá:

Inicializar o Terraform;
Baixar os providers necessários;
Preparar o diretório de trabalho.
2. Formatar os arquivos
terraform fmt

Para verificar todos os arquivos recursivamente:

terraform fmt -recursive
3. Validar a configuração
terraform validate

Resultado esperado:

Success! The configuration is valid.
4. Visualizar o plano
terraform plan

Esse comando mostra quais recursos serão criados ou modificados.

Exemplo do fluxo:

Código Terraform
       │
       ▼
terraform plan
       │
       ▼
Comparação com AWS
       │
       ▼
Recursos que serão criados
5. Criar o bucket
terraform apply

Revise o plano apresentado.

Para confirmar:

Enter a value: yes

Após a conclusão, o Terraform criará o bucket S3 utilizado para armazenar o state remoto.

📤 Outputs

Após a criação do bootstrap, o Terraform disponibiliza informações através dos outputs definidos em:

outputs.tf

Esses valores podem ser utilizados para identificar o bucket criado e configurar o backend da infraestrutura principal.

Para visualizar os outputs:

terraform output
🗄️ Utilização como Terraform Backend

Após a criação do bucket, a infraestrutura principal pode utilizar o S3 como backend remoto.

A configuração fica localizada em:

terraform/backend.tf

Fluxo:

bootstrap/s3
     │
     ▼
Cria S3 Bucket
     │
     ▼
S3 Terraform Backend
     │
     ▼
terraform/
     │
     ▼
Terraform State Remoto

A infraestrutura principal passa então a armazenar o estado centralmente no S3.

Isso evita depender exclusivamente de um arquivo local:

terraform.tfstate

Cada integrante não precisa possuir uma cópia independente do state como fonte principal da infraestrutura.

👥 Utilização em equipe

O backend remoto é especialmente importante em um projeto colaborativo.

Sem um backend remoto, poderia ocorrer o seguinte cenário:

Integrante A
└── terraform.tfstate local


Integrante B
└── terraform.tfstate local


Integrante C
└── terraform.tfstate local

Isso pode causar divergências entre o código e a infraestrutura.

Com o backend remoto:

                 AWS S3
                    │
                    ▼
          Terraform Remote State
             /        |        \
            ▼         ▼         ▼
      Integrante A  Integrante B  Integrante C

O state da infraestrutura fica centralizado.

⚠️ Importante

O bootstrap é uma infraestrutura especial.

O bucket S3 criado aqui é utilizado pela infraestrutura principal para armazenar seu state.

Portanto, não execute terraform destroy neste diretório sem antes verificar se o bucket está sendo utilizado como backend pela infraestrutura principal.

Destruir o bucket utilizado como backend pode causar problemas no gerenciamento do Terraform State.

Antes de qualquer alteração, verifique:

bootstrap/s3

e:

terraform/backend.tf
🧪 Comandos recomendados

Antes de aplicar alterações:

terraform fmt
terraform validate
terraform plan

Depois de revisar o plano:

terraform apply
📊 Fluxo completo do projeto

O bootstrap faz parte da primeira etapa do provisionamento da infraestrutura.

┌─────────────────────────────┐
│      BOOTSTRAP S3           │
│                             │
│  Criação do Backend Remoto  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   TERRAFORM REMOTE STATE    │
│                             │
│       Amazon S3 Bucket      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   INFRAESTRUTURA PRINCIPAL  │
│                             │
│  ├── VPC                    │
│  ├── Public Subnets         │
│  ├── Private Subnets        │
│  ├── Internet Gateway       │
│  ├── NAT Gateway            │
│  ├── Route Tables           │
│  └── Security Groups        │
└─────────────────────────────┘
🎯 Resumo

Este módulo de bootstrap é responsável por criar a infraestrutura inicial necessária para o gerenciamento centralizado do Terraform State.

Bootstrap
│
└── S3 Terraform Backend
    │
    ├── S3 Bucket
    ├── Terraform State
    └── Public Access Block

Após a execução do bootstrap, o bucket criado é utilizado como backend remoto pela infraestrutura principal do projeto.