terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
    }
    random = {
      source  = "hashicorp/random"
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

resource "teleport_provision_token" "grafana" {
  version = "v2"
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
  spec = {
    roles = ["App", "Node"]
    name  = random_string.token.result
  }
}

resource "aws_instance" "grafana" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  security_groups             = var.security_group_ids

  user_data = templatefile("${path.module}/userdata.tpl", {
    name             = "${var.env}-grafana"
    token            = teleport_provision_token.grafana.metadata.name
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    env              = var.env
    user             = local.user
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
    Name = "${local.user}-${var.env}-grafana"
  }
}