terraform {
  required_version = "~> 1.8.4"

  required_providers {
    demo-aws = {
      source = "hashicorp/aws"
      version = "~> 3.21"
    }
/*
    demo_azure = {
        source = ""
        version = ""
    }
*/
  }

  backend "s3" {
    bucket = "demo512"
    key = "terraform/state.tfstate"
    region = "us-east-1"
  }
}

provider demo-aws {
  profile = "default"
  region = "us-east-1"
  //access_key = "xyz"
  //secret_key = "xyz"
  alias = "aws_lab"
}


variable "vpc_cidr_block" {
    description = "vpc cidr block"
    default = "10.0.0.0/20"
    type = string
}

resource "aws_vpc" "demo-vpc" {
    provider = demo-aws.aws_lab
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "demo-vpc-tag"
        env: "dev"
    }
}

variable "subnet_cidr_block" {
    description = "subnet cidr block"
    default = ["10.0.10.0/32", "10.0.0.0/16"]
    type = list(string) 
}
variable "avail_zone" {}
variable "env_prefix" {}

resource "aws_subnet" "demo-subnet" {
    provider = demo-aws.aws_lab  
    vpc_id = aws_vpc.demo-vpc.id
    cidr_block = var.subnet_cidr_block[0]
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-demo-subnet-tag"
        env: "dev-subnet-1"
    }
}

resource "aws_subnet" "demo-subnet-2" {
    provider = demo-aws.aws_lab 
    vpc_id = aws_vpc.demo-vpc.id
    cidr_block = var.subnet_cidr_block[1]
    availability_zone = "us-east-1a"
    tags = {
        Name = "demo-subnet-tag"
    }
}

resource "aws_internet_gateway" "demo-igw" {
    provider = demo-aws.aws_lab
    vpc_id = aws_vpc.demo-vpc.id
}

# create the new route table. which is the best practice 
resource "aws_route_table" "demo-route-table" {
    vpc_id = aws_vpc.demo-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        # gateway id is the IGW id
        gateway_id = aws_internet_gateway.demo-igw.id
    }
    tags = {
        Name: "dev-rt"
    }
}


# Associate the subnet with the route table 
resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.demo-subnet.id
    route_table_id = aws_route_table.demo-route-table.id
}

variable "myip" {}

resource "aws_security_group" "demo-sg" {
    name = "demo-sg1"
    vpc_id = aws_vpc.demo-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol =  "tcp"
        cidr_blocks = [var.myip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol =  "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

# allow any traffic to leave from the server 
    egress {
        from_port = 0   // here zero means any ip 
        to_port = 0     // here also zero means any ip 
        protocol = "-1"     // -1 means all protocoll
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name : "dev-sg1"
    }
}

data "aws_ami" "latest-amazon-linux-image"{
    most_recent = true
    owners = ["amazon"]
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

variable "public-key-location" {}

/*
to create the public key in the local m/c 
this is stored in the ~/.ssh/<key-name>
ssh-keygen
# where to store key: /home/ec2-user/.ssh/test
cat ~/.ssh/<key-name>
# paste this whole string in the public_key = "whole-string"
but we do not want to push this key into the github which is accessible to all users 
# so we refence the file location 
After instance launched ssh to the ec2 instance 
to do this run the following command into the 
ssh ec2-user@<public-ip> -i <private-key-name with location/path>
ssh ec2-user@<public-ip> -i /home/ec2-user/.ssh/test
*/

resource "aws_key_pair" "demo-key" {
    # key_name = same
    key_name = "server-key"
    # public_key = "${file(var.public-key-location)}"
    public_key = file(var.public-key-location)
}


variable "ec2-type" {}

resource "aws_instance" "demo-ec2" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.ec2-type

    subnet_id = aws_subnet.demo-subnet.id
    vpc_security_group_ids = [aws_security_group.demo-sg.id]
    availability_zone = "us-east-1a"

    associate_public_ip_address = true
    key_name = aws_key_pair.demo-key.key_name
    # key_name = "deployer-key" # "same" # use key name directly here 

    tags = {
        Name = "dev-server-ec2"
    }

    # user_data = file("entry-script.sh")
    user_data = file("entry-script.sh")
    # once the terraform configures the infrastructure, then terraform will not wait for the instance to come up to run this script.
    # terraform will handover the this script to the cloud provider here its aws-cloud then it aws responsibility  to execute this after the instance will launch. 
}


/*
# this is to create the new key pair. this also delete the key if you terrafrom destroy command 
# ------------------------------
resource "aws_key_pair" "TF_key" {
  key_name   = "deployer-key"
  public_key = tls_private_key.rsa-key.public_key_openssh
}

# To create a ssh key 
# RSA key of size 4096 bits
resource "tls_private_key" "rsa-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# To store the private key in our pc
resource "local_file" "TF_key" {
  content  = tls_private_key.rsa-key.private_key_pem
  filename = "tfkey"
}
# ------------------------------
*/

output "ec2_public_ip"  {
    value = aws_instance.demo-ec2.public_ip 
}








/* 
# Just for reference purpose 

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

*/ 