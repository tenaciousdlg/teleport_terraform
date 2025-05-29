terraform {
  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 17.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

locals {
  user = lower(split("@", var.user)[0])
}

resource "random_string" "token" {
  length  = 32
  special = false
}

resource "teleport_provision_token" "agent" {
  version = "v2"
  spec = {
    roles = ["Node"]
    name  = random_string.token.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "aws_vpc" "main" {
  count                = var.create_network ? 1 : 0
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "main" {
  count      = var.create_network ? 1 : 0
  vpc_id     = aws_vpc.main[0].id
  cidr_block = var.cidr_subnet
}

resource "aws_security_group" "main" {
  count       = var.create_network ? 1 : 0
  vpc_id      = aws_vpc.main[0].id
  description = "Allow all egress"
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

resource "aws_instance" "ssh_node" {
  count                     = var.agent_count
  ami                       = var.ami_id
  instance_type             = var.instance_type
  subnet_id                 = var.subnet_id != null ? var.subnet_id : aws_subnet.main[0].id
  vpc_security_group_ids    = var.security_group_ids != null ? var.security_group_ids : [aws_security_group.main[0].id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/userdata.tpl", {
    token            = teleport_provision_token.agent.metadata.name
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    env              = var.env
    host             = "ssh-${count.index}"
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.user}-${var.env}-ssh-${count.index}"
  }
}