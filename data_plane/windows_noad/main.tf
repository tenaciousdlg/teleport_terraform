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
      version = "~> 16.0"
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
      "purpose"              = "teleport windows demo non-AD"
      "${var.aws_key_label}" = "${var.aws_value_label}"
      "teleport-cluster"     = "${var.proxy_service_address}"
    }
  }
}

provider "teleport" {
  addr               = "${var.proxy_service_address}:443"
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
  depends_on  = [aws_vpc.main]
  vpc_id      = aws_vpc.main.id
  name        = "allow_local"
  description = "allow private network traffic and internet egress"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_vpc]
    self        = true
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

data "aws_ami" "windows_server" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_windows_search}"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["801119661308"] # Amazon's AWS Windows AMI account ID
}

resource "aws_instance" "windows" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.private
  ]
  ami                         = data.aws_ami.windows_server.id
  instance_type               = "${var.windows_machine_size}"
  key_name                    = var.ssh_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.local.id]
  get_password_data           = true
  user_data = templatefile("${path.module}/config/windows.tftpl", {
    User     = "${var.win_user}"
    Password = random_string.windows.result
    Domain   = "${var.proxy_service_address}"
    teleport_version_channel = "${var.teleport_version_channel}"
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["${var.ami_amazonlinx_search}"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["137112412989"] # Amazon's AWS AMI account ID
}

resource "aws_instance" "linux_jump" {
  depends_on = [aws_vpc.main, aws_subnet.public]
  # Amazon Linux 2023 64-bit x86
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "${var.agent_machine_size}"
  key_name               = var.ssh_key
  vpc_security_group_ids = [aws_security_group.local.id]
  subnet_id              = aws_subnet.public.id
  user_data = templatefile("./config/userdata", {
    token                = teleport_provision_token.linux_jump.metadata.name
    windows_internal_dns = aws_instance.windows.private_dns
    domain               = var.proxy_service_address
    teleport_install_type = var.teleport_install_type
    teleport_install_upgrader = var.teleport_install_upgrader
    teleport_version_channel = var.teleport_version_channel
    teleport_ssh_label = var.teleport_ssh_label
    teleport_windows_label = var.teleport_windows_label
    ssh_enhanced_recording_bool = var.ssh_enhanced_recording_bool
    agent_machine_name = var.agent_machine_name
    teleport_join_method = var.teleport_join_method
    teleport_token_name = var.teleport_token_name
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
