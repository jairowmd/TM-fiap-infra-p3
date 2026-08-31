# Identificação / Naming / Tagging
variable "project_name" {
  description = "Nome do projeto, usado para compor nomes e tags dos recursos (ex.: tm-fiap-p3)."
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (ex.: dev, staging, prod), usado para compor nomes e tags."
  type        = string
}

# Rede — recebido do módulo vpc (Jairo)

variable "vpc_id" {
  description = "ID da VPC onde o cluster EKS será criado (output do módulo vpc)."
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas onde o control plane (ENIs) e os worker nodes serão provisionados (output do módulo vpc)."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "O EKS exige subnets em pelo menos 2 Availability Zones distintas."
  }
}

variable "cluster_additional_security_group_ids" {
  description = "Security Groups adicionais a anexar ao control plane do EKS, além da Security Group criada automaticamente pelo próprio EKS. Use apenas se surgir uma necessidade específica (ex.: acesso de uma SG de bastion). Vazio por padrão."
  type        = list(string)
  default     = []
}

# Cluster

variable "kubernetes_version" {
  description = "Versão do Kubernetes do control plane EKS. Deve ser uma versão em standard support — conferir antes de alterar em https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Se true, o endpoint da API do Kubernetes fica acessível pela internet (restrito pelos CIDRs de cluster_endpoint_public_access_cidrs). O acesso privado dentro da VPC está sempre habilitado, independentemente deste valor."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs autorizados a acessar o endpoint público da API do Kubernetes. Para uso real, restrinja ao IP/rede de quem roda kubectl em vez de manter aberto para a internet."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_principal_arns" {
  description = "ARNs de usuários/roles IAM que devem receber acesso de administrador ao cluster via EKS Access Entries. Sem isso, ninguém consegue autenticar via kubectl após a criação do cluster — descubra o seu ARN com 'aws sts get-caller-identity'."
  type        = list(string)
  default     = []
}

# Managed Node Group
variable "node_group_config" {
  description = "Configuração do Managed Node Group: tipos de instância, capacidade e escala."
  type = object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size      = number
  })

  default = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    disk_size      = 20
  }
}

# Add-ons
variable "enable_metrics_server" {
  description = "Se true, instala o add-on metrics-server, necessário para 'kubectl top' e para HPA (Horizontal Pod Autoscaler) baseado em CPU/memória."
  type        = bool
  default     = true
}
