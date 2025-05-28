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

data "http" "teleport_db_ca_cert" {
  url = "https://${var.proxy_address}/webapi/auth/export?type=db-client"
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

data "aws_ami" "windows_server" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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
  cidr_subnet      = "10.0.1.0/24"
}

module "mysql_registration" {
  source        = "../../modules/registration"
  resource_type = "database"
  name          = "mysql-${var.env}"
  description   = "MySQL database in ${var.env} full deployment"
  protocol      = "mysql"
  uri           = "localhost:3306"
  ca_cert_chain = module.mysql_instance.ca_cert
  labels = {
    tier = var.env
  }
}

module "ssh_node" {
  source             = "../../modules/ssh_node"
  env                = var.env
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  agent_count        = 2
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = "t3.micro"
  create_network     = false
  subnet_id          = module.mysql_instance.subnet_id
  security_group_ids = [module.mysql_instance.security_group_id]
}

module "windows_instance" {
  source = "../../modules/windows_instance"

  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version

  ami_id           = data.aws_ami.windows_server.id
  instance_type    = "t3.medium"

  create_network     = false
  subnet_id          = module.mysql_instance.subnet_id
  security_group_ids = [module.mysql_instance.security_group_id]
}

module "linux_desktop_service" {
  source = "../../modules/linux_desktop_service"

  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version

  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"

  create_network       = false
  subnet_id            = module.mysql_instance.subnet_id
  security_group_ids   = [module.mysql_instance.security_group_id]
  windows_internal_dns = module.windows_instance.private_dns
  windows_hosts = [
    {
      name    = module.windows_instance.hostname
      address = "${module.windows_instance.private_ip}:3389"
    }
  ]
}
