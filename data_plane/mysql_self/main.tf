terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 17.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "teleport.dev/creator" = var.user
      "tier"                 = var.env
      "ManagedBy"            = "terraform"
    }
  }
}

provider "teleport" {
  addr = "${var.proxy_address}:443"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "http" "teleport_db_ca_cert" {
  url = "https://${var.proxy_address}/webapi/auth/export?type=db-client"
}

module "mysql_instance" {
  source           = "../../modules/mysql_instance"
  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version
  teleport_db_ca   = data.http.teleport_db_ca_cert.response_body
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = "t3.small"
  create_network   = true
  cidr_vpc         = "10.0.0.0/16"
  cidr_subnet      = "10.0.2.0/24"
}

module "mysql_registration" {
  source            = "../../modules/registration"
  name              = "mysql-${var.env}"
  description       = "MySQL database in ${var.env}"
  uri               = "localhost:3306"
  protocol          = "mysql"
  ca_cert_chain     = module.mysql_instance.ca_cert
  labels = {
    tier = var.env
  }
}
