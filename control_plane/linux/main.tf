##################################################################################
# PROVIDERS 
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.93"
    }
  }
}
provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      "teleport.dev/creator" = var.user
      "tier"                 = "dev"
      "ManagedBy"            = "terraform"
    }
  }
}
##################################################################################
# DATA SOURCES
##################################################################################
# used for creating subdomain on existing zone. Skip DNS steps if unneeded
data "aws_route53_zone" "main" {
  name = var.parent_domain
}
data "http" "myip" { # remove when unneeded
  url = "http://ipv4.icanhazip.com"
}
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
  owners = ["099720109477"] # aws ec2 describe-images --image-ids ami-024e6efaf93d85776 --output json | jq '.Images[] | {Platform, OwnerId}'
}
##################################################################################
# RESOURCES
##################################################################################
# networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # add variable for this
  enable_dns_hostnames = true
  enable_dns_support   = true
}
resource "aws_security_group" "main" {
  name        = "linux_teleport_network"
  description = "allows proxy peered setup for self hosted deployment managed by ${var.user}"
  vpc_id      = aws_vpc.main.id
  ingress { # remove when unneeded
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }
  ingress { # multiplexed port for teleport 
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #aws way of saying everything
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
resource "aws_subnet" "main" {
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
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
# compute 
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"   #add variable for this 
  key_name               = var.key_name #remove when unneeded
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = aws_subnet.main.id
  user_data = templatefile("./config/userdata1", {
    license = file("${path.module}/../license.pem")
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    user = var.user
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted             = true
    delete_on_termination = true
  }
  tags = {
    Name = "${var.user}-selfhost"
    Role = "auth/proxy service"
  }
}
# dns
# creates DNS record for teleport cluster on eks
resource "aws_route53_record" "cluster_endpoint" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.proxy_address
  type    = "A"
  ttl     = "300"
  records = [aws_instance.main.public_ip]
}

# creates wildcard record for teleport cluster on eks 
resource "aws_route53_record" "wild_cluster_endpoint" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.proxy_address}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.main.public_ip]
}
