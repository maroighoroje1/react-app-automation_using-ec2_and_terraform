terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# -------------------------
# Generate SSH Key
# -------------------------
resource "tls_private_key" "myapp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "myapp_key_pair" {
  key_name   = "reactapp-key"
  public_key = tls_private_key.myapp_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.myapp_key.private_key_pem
  filename        = "${path.module}/reactapp-key.pem"
  file_permission = "600"
}

# -------------------------
# VPC
# -------------------------
resource "aws_vpc" "myapp_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
}

resource "aws_subnet" "myapp_subnet" {
  vpc_id                  = aws_vpc.myapp_vpc.id
  cidr_block              = var.subnet_cidr_block
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "myapp_igw" {
  vpc_id = aws_vpc.myapp_vpc.id
}

resource "aws_route_table" "myapp_rt" {
  vpc_id = aws_vpc.myapp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp_igw.id
  }
}

resource "aws_route_table_association" "myapp_rta" {
  subnet_id      = aws_subnet.myapp_subnet.id
  route_table_id = aws_route_table.myapp_rt.id
}

# -------------------------
# Security Group
# -------------------------
resource "aws_security_group" "myapp_sg" {
  name   = "reactapp-sg"
  vpc_id = aws_vpc.myapp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Ubuntu AMI
# -------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# -------------------------
# EC2 Instance
# -------------------------
resource "aws_instance" "myapp_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.myapp_subnet.id
  key_name               = aws_key_pair.myapp_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.myapp_sg.id]

  tags = {
    Name = "reactapp-server"
  }
}

# -------------------------
# Run Ansible
# -------------------------
resource "null_resource" "run_ansible" {
  depends_on = [aws_instance.myapp_server]

  provisioner "local-exec" {
    command = <<EOT
ansible-playbook -i '${aws_instance.myapp_server.public_ip},' \
  --private-key ./reactapp-key.pem \
  -u ubuntu \
  ../ansible/deploy-react.yaml
EOT
  }
}