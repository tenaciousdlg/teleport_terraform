##################################################################################
# CONFIGURATION - added for Terraform 0.14
##################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    # optional and used for DNS hosting
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  region = var.aws_region
}
# optional and used for DNS hosting 
provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_key
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
  # Command to source below
  # aws ec2 describe-images --image-ids ami-024e6efaf93d85776 --output json | jq '.Images[] | {Platform, OwnerId}'
  owners = ["099720109477"] 
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

##################################################################################
# RESOURCES
##################################################################################
# https://serverfault.com/questions/1084705/unable-to-ssh-into-a-terraform-created-ec2-instance
resource "aws_key_pair" "main" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_pub
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.cidr_subnet
}

resource "aws_security_group" "main" {
  name   = var.sg
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main.id
  security_groups             = ["${aws_security_group.main.id}"]
  subnet_id                   = aws_subnet.main.id
  user_data = templatefile("./config/userdata", {
    domain = var.proxy_service_address
    email  = var.cloudflare_email
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
    ignore_changes = [ami]
  }
  tags = {
    Name = var.name
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_public_dns" {
  value = aws_instance.main.public_dns
}
output "aws_instance_public_ip" {
  value = aws_instance.main.public_ip
}
output "next_steps" {
  value = "login and run 'sudo tctl users add teleport-admin --roles=editor,access --logins=root,ubuntu,ec2-user' if this is a new teleport cluster"
}
##################################################################################