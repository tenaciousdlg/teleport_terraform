terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    random = {
      source  = "hashicorp/random"
    }
  }
}

locals {
  user = lower(split("@", var.user)[0])
}

resource "random_string" "windows" {
  length  = 40
  special = false
}

resource "aws_vpc" "main" {
  count = var.create_network ? 1 : 0
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "main" {
  count                   = var.create_network ? 1 : 0
  cidr_block              = var.cidr_subnet
  vpc_id                  = aws_vpc.main[0].id
  map_public_ip_on_launch = true
}

resource "aws_security_group" "main" {
  count       = var.create_network ? 1 : 0
  name        = "allow_windows_local"
  description = "Allow Windows traffic"
  vpc_id      = aws_vpc.main[0].id
  ingress {
    description = "Allow RDP from within VPC"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.cidr_vpc]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  count  = var.create_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id
}

resource "aws_route_table" "main" {
  count  = var.create_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
}

resource "aws_route_table_association" "main" {
  count          = var.create_network ? 1 : 0
  subnet_id      = aws_subnet.main[0].id
  route_table_id = aws_route_table.main[0].id
}

resource "aws_instance" "windows" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id = var.subnet_id != null ? var.subnet_id : aws_subnet.main[0].id
  security_groups = var.security_group_ids != null ? var.security_group_ids : [aws_security_group.main[0].id]
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/windows.tpl", {
    User                     = local.user
    Password                 = random_string.windows.result
    Domain                   = var.proxy_address
    Env                      = var.env
    TeleportVersion          = var.teleport_version
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted             = true
    delete_on_termination = true
  }
  tags = {
    Name = "${local.user}-${var.env}-windows"
  }
}
