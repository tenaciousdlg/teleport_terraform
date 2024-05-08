##################################################################################
# PROVIDERS
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "15.3.0"
    }
  }
  required_version = ">= 1.2.0"
}
provider "aws" {
  region = var.aws_region
}
provider "teleport" {
  addr               = "${var.proxy_service_address}:443"
  identity_file_path = var.identity_path
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
##################################################################################
# RESOURCES
##################################################################################
resource "random_string" "bot_token" {
  length           = 32
  special          = true
  override_special = "-.+"
}

resource "teleport_provision_token" "bot_ansible" {
  version = "v2"
  metadata = {
    expires     = timeadd(timestamp(), "1h")
    description = "Bot join token for ${local.bot_name} managed by Terraform"
    name        = random_string.bot_token.result
  }
  spec = {
    roles       = ["Bot"]
    bot_name    = local.bot_name
    join_method = "token"
  }
}

locals {
  bot_name = "ansible"
}

resource "teleport_bot" "ansible" {
  name     = local.bot_name
  token_id = teleport_provision_token.bot_ansible.metadata.name
  roles    = [teleport_role.ansible.id]
}

resource "teleport_role" "ansible" {
  version = "v7"
  metadata = {
    name        = "ansible-role"
    description = "Role to allow Ansible access. This should be adjusted to your service of choice"
  }
  spec = {
    allow = {
      logins = ["root"] # Replace this with the system user Ansible will use to login
      node_labels = {
        "*" : ["*"] # Adjust node labels to match the nodes Ansible needs to access. In this example we are saying all nodes and login as root
      }
    }
  }
}

resource "teleport_user" "ansible_admin" {
  version = "v2"
  depends_on = [
    teleport_role.ansible
  ]
  metadata = {
    name        = "ansible-admin"
    description = "user for ansible automation"
  }
  spec = {
    roles = [teleport_role.ansible.id]
  }
}

resource "random_string" "main_token" {
  length = 32
}

resource "teleport_provision_token" "main" {
  version = "v2"
  spec = {
    roles = [
      "Node",
    ]
    name = random_string.main_token.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  user_data = templatefile("./config/userdata", {
    token     = teleport_provision_token.main.metadata.name
    bot_token = teleport_bot.ansible.token_id
    domain    = var.proxy_service_address
    major     = var.teleport_major_version
  })

  // The following two blocks adhere to security best practices.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }
  tags = {
    Name = var.ec2_name
  }
}
##################################################################################