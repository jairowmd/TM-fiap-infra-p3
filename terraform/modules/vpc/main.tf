# # Criação da VPC
resource "aws_vpc" "this" {
  # Bloco CIDR da VPC, vindo da variável vpc_cidr
  cidr_block = var.vpc_cidr

  # Tags para identificar e organizar o recurso
  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

# # Subnets Públicas
resource "aws_subnet" "public" {
  # Cria uma subnet para cada CIDR listado em var.public_subnet_cidrs
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Instâncias recebem IP público automaticamente

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Public"
  }
}

# # Subnets Privadas
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Private"
  }
}

# # Internet Gateway (necessário para saída à internet das subnets públicas)
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}

# # Tabela de Rotas Pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Rota padrão para internet via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Public"
  }
}

# # Associação das Subnets Públicas à Tabela de Rotas Pública
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# # Tabela de Rotas Privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  # Rota padrão para internet via NAT Gateway (para subnets privadas)
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Private"
  }
}

# # Associação das Subnets Privadas à Tabela de Rotas Privada
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# # Elastic IP para o NAT Gateway (IP público fixo)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Project     = var.project_name
    Environment = var.environment
  }
}

# # NAT Gateway (permite que subnets privadas acessem a internet)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # NAT precisa estar em uma subnet pública

  # Garante que o Internet Gateway seja criado antes
  depends_on = [aws_internet_gateway.this]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway"
    Project     = var.project_name
    Environment = var.environment
  }
}