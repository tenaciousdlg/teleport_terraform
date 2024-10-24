##################################################################################
# CONFIGURATION 
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "15.3.0"
    }
  }
}
##################################################################################
# PROVIDERS
##################################################################################
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "teleport.dev/creator" = "dlg@goteleport.com"
      "Purpose"              = "teleport mysql self hosted demo"
      "Env"                  = "dev"
    }
  }
}

provider "teleport" {
  addr               = "${var.proxy_service_address}:443"
  identity_file_path = var.identity_path
}

provider "vault" {
  address = "http://127.0.0.1:8200"
}

provider "random" {
}
##################################################################################
# DATA SOURCES
##################################################################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # aws ec2 describe-images --image-ids ami-024e6efaf93d85776 --output json | jq '.Images[] | {Platform, OwnerId}'
}

data "vault_kv_secret" "mysql" {
  path = "secret/mysql"
}
##################################################################################
# RESOURCES
##################################################################################
# instance networking
resource "random_string" "uuid" {
  length  = 4
  special = false
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_security_group" "main" {
  depends_on  = [aws_vpc.main]
  vpc_id      = aws_vpc.main.id
  name        = "egress out"
  description = "allow only egress networking"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.cidr_subnet
}

resource "aws_route_table" "main" {
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  vpc_id     = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "random_string" "token" {
  length = 32
}
# https://goteleport.com/docs/reference/terraform-provider/#teleport_provision_token
resource "teleport_provision_token" "db" {
  version = "v2"
  spec = {
    roles = [
      "Db",
      "Node",
    ]
    name = random_string.token.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.main.id]
  subnet_id                   = aws_subnet.main.id
  user_data = templatefile("./config/userdata", {
    token  = teleport_provision_token.db.metadata.name
    domain = var.proxy_service_address
    sqlcas = base64decode(data.vault_kv_secret.mysql.data["cas"])
    sqlcrt = base64decode(data.vault_kv_secret.mysql.data["crt"])
    sqlkey = base64decode(data.vault_kv_secret.mysql.data["key"])
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted = true
  }
  # Prevents resource being recreated for minor versions of AMI 
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
##################################################################################