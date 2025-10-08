terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region # ← Removed quotes
  profile = "iamadmin-gen"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "devops-portfolio"
      Environment = var.environment # ← Removed quotes
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.common_tags
}

# Security Group Module
module "security" {             # ← Changed name to match reference below
  source = "./modules/security" # ← Make sure folder name matches

  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from anywhere"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from anywhere"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["66.235.88.153/32"]
      description = "Allow SSH from my IP"
    }
  ]
  tags = var.common_tags
}

# EC2 Instance Module
module "ec2" {
  source = "./modules/ec2"

  environment       = var.environment
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security.security_group_id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from ${var.environment}!</h1>" > /var/www/html/index.html
              EOF

  tags = var.common_tags
}