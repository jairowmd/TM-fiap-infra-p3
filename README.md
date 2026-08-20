# Security Groups Module

## Descrição

Este módulo Terraform é responsável pela criação e gerenciamento dos Security Groups utilizados pela infraestrutura do projeto **TM FIAP Infra P3**.

Os Security Groups funcionam como firewalls virtuais na AWS, controlando o tráfego de entrada e saída dos recursos da infraestrutura.

Este módulo faz parte da camada de **Infra Core** do projeto e tem como objetivo fornecer uma base de segurança reutilizável para os demais componentes da arquitetura.

---

## Responsabilidade

Este módulo é responsável por:

- Criar Security Groups na AWS
- Definir regras de entrada (Ingress)
- Definir regras de saída (Egress)
- Permitir comunicação controlada entre componentes da infraestrutura
- Aplicar o princípio do menor privilégio
- Exportar os IDs dos Security Groups para utilização por outros módulos

A criação e gerenciamento do cluster EKS não fazem parte da responsabilidade deste módulo.

---

## Arquitetura

A infraestrutura do projeto possui a seguinte separação inicial:

```text
Internet
    │
    ▼
Ingress / Load Balancer
    │
    ▼
Aplicações Kubernetes
    │
    ├── RDS
    │
    ├── ElastiCache
    │
    └── Outros serviços AWS