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
      version = "~> 16.0"
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
      "teleport.dev/creator" = var.user
      "Purpose"              = "teleport machine id with ansible demo"
      "tier"                  = "dev"
    }
  }
}
provider "teleport" {
  addr               = "${var.proxy_address}:443"
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
    name        = "ansible-bot"
    description = "Role to allow Ansible access. This should be adjusted to your service of choice"
  }
  spec = {
    allow = {
      logins = ["ubuntu", "ec2-user"] # Replace this with the system user Ansible will use to login
      node_labels = {
        "*" : ["*"] # Adjust node labels to match the nodes Ansible needs to access. In this example we are saying all nodes and login as ansible 
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

resource "random_string" "uuid" {
  length  = 4
  special = false
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_security_group" "egress" {
  depends_on  = [aws_vpc.main]
  vpc_id      = aws_vpc.main.id
  name        = "allow outbound"
  description = "allow egress access to internet for ec2 instances"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  depends_on              = [aws_vpc.main]
  cidr_block              = var.cidr_subnet
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
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
  depends_on     = [aws_subnet.main, aws_route_table.main]
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.egress.id]
  user_data = templatefile("./config/userdata", {
    token     = teleport_provision_token.main.metadata.name
    bot_token = teleport_bot.ansible.token_id
    domain    = var.proxy_address
    major     = var.teleport_version
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
    Name = "${split(".", var.proxy_address)[0]}-machineid-ansible"
  }
}
##################################################################################