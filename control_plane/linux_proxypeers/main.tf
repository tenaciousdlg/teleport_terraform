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
  region = var.region
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
# used for creating subdomain on existing zone. Remove DNS steps if unneeded
data "aws_route53_zone" "main" {
  name = var.parent_domain
}
# data source for Amazon Linux 2023 (used due to aws cli/s3 workflow)
data "aws_ami" "main" {
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
# used for naming convention clean up (i.e. resource naming from jsmith@example.com-bucket to jsmith-bucket)
locals {
  username = lower(split("@", var.user)[0])
}
##################################################################################
# RESOURCES
##################################################################################
# networking
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
}
resource "aws_security_group" "main" {
  name        = "${local.username}_linux_teleport_network"
  description = "allows proxy peered setup for self hosted deployment managed by ${local.username}"
  vpc_id      = aws_vpc.main.id
  ingress { # multiplexed port for teleport; allows remote HTTPS access and agent joining 
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress { # allows proxies to peer
    from_port   = 3021
    to_port     = 3021
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  ingress { # allows peers to dial auth
    from_port   = 3025
    to_port     = 3025
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
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
  cidr_block              = var.subnet
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
# storage
resource "aws_s3_bucket" "main" {
  bucket        = "${local.username}proxypeers"
  force_destroy = true
}
# iam
resource "aws_iam_role" "ec2_role" {
  name = "${local.username}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "s3_access" {
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.username}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
# compute 
resource "aws_instance" "main" {
  ami                    = data.aws_ami.main.id
  instance_type          = var.ec2main_size
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = aws_subnet.main.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data = templatefile("./config/userdata1", {
    bucket           = aws_s3_bucket.main.bucket
    license          = file("${path.module}/../license.pem")
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    user             = var.user
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
    Name = "${local.username}-selfhost"
    Role = "auth/proxy service"
  }
}
resource "aws_instance" "proxy" {
  count                  = var.proxy_count
  ami                    = data.aws_ami.main.id
  instance_type          = var.ec2proxy_size
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = aws_subnet.main.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data = templatefile("./config/userdata2", {
    auth_ip          = aws_instance.main.private_ip
    bucket           = aws_s3_bucket.main.bucket
    name             = "proxypeer-${count.index}"
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    user             = var.user
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
    Name = "${local.username}-selfhost-peer-${count.index}"
    Role = "proxy service-${count.index}"
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
##################################################################################
# OUTPUTS 
##################################################################################
output "teleport_user_login_details" {
  value       = "aws s3 cp s3://${aws_s3_bucket.main.bucket}/user -"
  description = "provides command to run to retrieve login details"
}