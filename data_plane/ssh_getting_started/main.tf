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

data "aws_ami" "linux" {
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

module "ssh_nodes" {
  source = "../../modules/ssh_node"

  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version

  agent_count   = 3
  ami_id        = data.aws_ami.linux.id
  instance_type = "t3.micro"

  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}