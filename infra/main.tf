provider "aws" {
  region = "us-east-2" 
  profile = "pessoal" # Defina a região AWS apropriada
}

resource "aws_ecr_repository" "api_repository" {
  name = "api-coders-devops"
}
