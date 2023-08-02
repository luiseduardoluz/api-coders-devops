provider "aws" {
  region = "sa-east-1" 
  profile = "pessoal" # Defina a região AWS apropriada
}

resource "aws_ecr_repository" "api_repository" {
  name = "api-coders-devops"
}

resource "aws_ecr_repository_policy" "api_repository_policy" {
  repository = aws_ecr_repository.api_repository.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid       = "AllowPushPull"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetLifecyclePolicy",
        ]
      }
    ]
  })
}

# Criação da VPC
resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "coders-vpc"
  }
}

# Criação de uma Subnet pública na VPC
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.example_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "sa-east-1a"  # Substitua pela AZ desejada
  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.example_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "sa-east-1b"  # Substitua pela AZ desejada
  tags = {
    Name = "public-subnet-1b"
  }
}

# Criação do Internet Gateway (IGW)
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.example_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example_igw.id
}

# Criação do Grupo de Segurança (Security Group) para o cluster ECS
resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs-sg-"
  vpc_id      = aws_vpc.example_vpc.id

  # Regra de entrada para permitir tráfego HTTP na porta 80
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída para permitir todo o tráfego
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Criação do Cluster ECS
resource "aws_ecs_cluster" "example_cluster" {
  name = "coders-cluster"
}

# Criação da Definição da Tarefa (Task Definition) do ECS
resource "aws_ecs_task_definition" "example_task" {
  family                   = "coders-task"
  execution_role_arn       = aws_iam_role.task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name   = "coders-container"
    image  = aws_ecr_repository.api_repository.repository_url # Substitua pelo URL da imagem Docker do seu aplicativo
    cpu    = 256
    memory = 512
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
  }])
}

# Criação do Serviço ECS
resource "aws_ecs_service" "example_service" {
  name  = "coders-service"
  cluster = aws_ecs_cluster.example_cluster.id
  task_definition = aws_ecs_task_definition.example_task.arn
  desired_count = 1
  launch_type = "FARGATE"

    network_configuration {
        subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
        security_groups = [aws_security_group.ecs_sg.id]
        assign_public_ip = true
    }
}

# Criação da Função de Execução do Task (Fargate)
resource "aws_iam_role" "task_execution" {
  name = "ecs-coders-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

