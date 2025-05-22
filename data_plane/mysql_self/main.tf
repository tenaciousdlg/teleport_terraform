##################################################################################
# CONFIGURATION / PROVIDERS
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 16.0"
    }
  }
}
# allows creation of aws resources
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "teleport.dev/creator" = var.user
      "Purpose"              = "teleport mysql self hosted demo"
      "tier"                 = "dev"
    }
  }
}
# allows creation of teleport resources
provider "teleport" {
  addr = "${var.proxy_address}:443"
}
# used for custom CA per https://goteleport.com/docs/enroll-resources/database-access/enroll-self-hosted-databases/mysql-self-hosted/#step-24-create-a-certificatekey-pair
provider "tls" {
}
# used for random data with ids/tokens
provider "random" {
}
##################################################################################
# DATA SOURCES / LOCALS
##################################################################################
# dynamically sources AMI for ubuntu 22.04
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
  owners = ["amazon"] 
}
# data source for Teleport DB CA
data "http" "teleport_db_ca_cert" {
  url = "https://${var.proxy_address}/webapi/auth/export?type=db-client"
}
##################################################################################
# RESOURCES
##################################################################################
# instance networking
resource "random_string" "uuid" {
  length  = 4
  special = false
}
# TESTING
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "example"
    organization = "example"
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_cert_request" "server_csr" {
  private_key_pem = tls_private_key.server_key.private_key_pem

  subject {
    common_name  = "mysql.example.internal" #mysql server hostname
    organization = "example org"
  }

  dns_names = [
    "mysql.example.internal",
    "localhost",
    "127.0.0.1"
  ]
}
resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem   = tls_cert_request.server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
# provision token for db and ssh services
resource "teleport_provision_token" "db" { # https://goteleport.com/docs/reference/terraform-provider/resources/provision_token/
  version = "v2"
  spec = {
    roles = [
      "Db",
      "Node",
    ]
    name = random_string.uuid.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}
# provision db for Teleport to detect
# https://goteleport.com/docs/reference/terraform-provider/resources/database/
resource "teleport_database" "mysql" {
  version = "v3"
  metadata = {
    name        = "test-mysql"
    description = "teleport-managed MySQL for dev"
    labels = {
      tier                   = "dev"
      "teleport.dev/origin"  = "dynamic"
    }
  }
  spec = {
    protocol = "mysql"
    uri      = "localhost:3306"
    tls = {
      ca_cert = "${tls_self_signed_cert.ca_cert.cert_pem}"
    }
  }
}
# aws networking 
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
# creates ec2 instance
resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.main.id]
  subnet_id                   = aws_subnet.main.id
  user_data = templatefile("./config/userdata", {
    token   = teleport_provision_token.db.metadata.name
    domain  = var.proxy_address
    major   = var.teleport_version
    ca      = tls_self_signed_cert.ca_cert.cert_pem
    cert    = tls_locally_signed_cert.server_cert.cert_pem
    key     = tls_private_key.server_key.private_key_pem
    tele_ca = data.http.teleport_db_ca_cert.response_body
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  # Prevents resource being recreated for minor versions of AMI 
  lifecycle {
    ignore_changes = [ami, user_data]
  }
  tags = {
    Name = "${split(".", var.proxy_address)[0]}-mysql"
  }
}
##################################################################################