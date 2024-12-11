terraform {
  required_version = "~> 1.8.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.21"
    }
  }

  backend "s3" {
    bucket = "demo512"
    key    = "terraform/state.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
  alias   = "aws_lab"
}

# Variables
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zone" {
  description = "Availability zone for the subnets"
  type        = string
}

variable "env_prefix" {
  description = "Environment prefix for naming resources"
  type        = string
}

variable "my_ip" {
  description = "Your IP address for SSH access"
  type        = string
}

variable "public_key_location" {
  description = "Path to your public key file"
  type        = string
}

variable "ec2_instance_type" {
  description = "Type of EC2 instance"
  type        = string
}

# Data Sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Resources
resource "aws_vpc" "demo_vpc" {
  provider   = aws.aws_lab
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "demo-vpc"
    Env  = "dev"
  }
}

resource "aws_subnet" "demo_subnet_1" {
  provider          = aws.aws_lab
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = var.subnet_cidr_blocks[0]
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.env_prefix}-demo-subnet-1"
    Env  = "dev"
  }
}

resource "aws_subnet" "demo_subnet_2" {
  provider          = aws.aws_lab
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = var.subnet_cidr_blocks[1]
  availability_zone = "us-east-1a"

  tags = {
    Name = "demo-subnet-2"
  }
}

resource "aws_internet_gateway" "demo_igw" {
  provider = aws.aws_lab
  vpc_id   = aws_vpc.demo_vpc.id
}

resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-route-table"
  }
}

resource "aws_route_table_association" "demo_subnet_assoc" {
  subnet_id      = aws_subnet.demo_subnet_1.id
  route_table_id = aws_route_table.demo_route_table.id
}

resource "aws_security_group" "demo_sg" {
  name   = "demo-sg"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-sg"
  }
}

resource "aws_key_pair" "demo_key" {
  key_name   = "demo-key"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "demo_ec2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.demo_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.demo_sg.id]
  availability_zone           = "us-east-1a"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.demo_key.key_name

  tags = {
    Name = "demo-ec2-instance"
  }

  user_data = file("entry-script.sh")
}

# Outputs
output "aws_ami_id" {
  value = data.aws_ami.amazon_linux.id
}

output "ec2_public_ip" {
  value = aws_instance.demo_ec2.public_ip
}
