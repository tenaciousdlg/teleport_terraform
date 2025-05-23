terraform {
  required_providers {
    teleport = {
      source = "terraform.releases.teleport.dev/gravitational/teleport"
    }
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_string" "token" {
  count  = var.agent_count
  length = 32
  special = false
}

resource "teleport_provision_token" "agent" {
  count   = var.agent_count
  version = "v2"
  spec = {
    roles = ["Node"]
    name  = random_string.token[count.index].result
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
  count                   = var.create_network ? 1 : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.cidr_subnet
  map_public_ip_on_launch = true
}

resource "aws_security_group" "egress" {
  count  = var.create_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ssh_node" {
  count                       = var.agent_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.create_network ? aws_subnet.main[0].id : var.subnet_id
  vpc_security_group_ids      = var.create_network ? [aws_security_group.egress[0].id] : var.security_group_ids
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/userdata.tpl", {
    token            = teleport_provision_token.agent[count.index].metadata.name
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    hostname         = "ssh-${var.env}-${count.index}"
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted             = true
    delete_on_termination = true
  }
}