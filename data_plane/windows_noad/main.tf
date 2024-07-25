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
      version = "~> 15.0"
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
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
      "Purpose" = "teleport windows demo non-AD"
      "Env"     = "dev"
    }
  }
}

provider "teleport" {
  addr               = "${var.proxy_service_address}:443"
  identity_file_path = var.identity_path
}

provider "random" {
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

resource "aws_security_group" "local" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
  name        = "allow_local"
  description = "allow private network traffic and internet egress"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_vpc]
  }
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

resource "aws_subnet" "public" {
  depends_on              = [aws_vpc.main]
  cidr_block              = var.cidr_subnet
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
}

resource "aws_subnet" "private" {
  depends_on = [aws_vpc.main]
  cidr_block = var.cidr_subnet2
  vpc_id     = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  vpc_id     = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  vpc_id     = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public, aws_route_table.public]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private, aws_route_table.private]
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# windows instance configuration
## Add data source for Windows AMI
resource "random_string" "windows" {
  length = 40
}

resource "aws_instance" "windows" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.private
  ]
  ami                         = "ami-0b2167681856cd65e"
  instance_type               = "t3.medium"
  key_name                    = var.ssh_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.local.id]
  get_password_data           = true
  user_data = templatefile("${path.module}/config/windows.tftpl", {
    User     = "${var.win_user}"
    Password = random_string.windows.result
    Version  = "${var.teleport_version}"
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted             = true
    delete_on_termination = true
  }
}
# linux instance configuration 
## add Data Source for Linux AMI 
resource "random_string" "token" {
  length = 32
}

resource "teleport_provision_token" "linux_jump" {
  version = "v2" # required > teleport 15
  spec = {
    roles = [
      "Node",
      "WindowsDesktop",
    ]
    name = random_string.token.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "aws_instance" "linux_jump" {
  depends_on = [aws_vpc.main, aws_subnet.public]
  # Amazon Linux 2023 64-bit x86
  ami                    = "ami-01103fb68b3569475"
  instance_type          = "t3.micro"
  key_name               = var.ssh_key
  vpc_security_group_ids = [aws_security_group.local.id]
  subnet_id              = aws_subnet.public.id
  user_data = templatefile("./config/userdata", {
    token                = teleport_provision_token.linux_jump.metadata.name
    windows_internal_dns = aws_instance.windows.private_dns
    domain               = var.proxy_service_address
  })
  // The following two blocks adhere to security best practices.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted = true
  }
}
##################################################################################
# OUTPUT
##################################################################################
output "desktop_name_in_teleport" {
  value = aws_instance.windows.private_dns
}
##################################################################################