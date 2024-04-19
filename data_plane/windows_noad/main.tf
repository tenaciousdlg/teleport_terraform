##################################################################################
# CONFIGURATION 
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "15.2.0"
    }
  }
}
##################################################################################
# PROVIDERS
##################################################################################
provider "aws" {
  region = var.aws_region
}
provider "teleport" {
  addr               = "${var.proxy_service_address}:443"
  identity_file_path = "/tmp/terraform-output/identity"
}
provider "random" {

}
##################################################################################
##################################################################################
# DATA SOURCES
##################################################################################
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}
##################################################################################
# RESOURCES
##################################################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_security_group" "ssh" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "dlg-sg"
  }
  name        = "allow local traffic"
  description = "traffic for private net and egress"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "local" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "private net"
  }
  name        = "allow_local"
  description = "allow private network traffic"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
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
  tags = {
    Name = "dlg-ig"
  }
}

resource "aws_subnet" "public" {
  depends_on              = [aws_vpc.main]
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
  tags = {
    Name = "dlg_public_net"
  }
}

resource "aws_subnet" "private" {
  depends_on = [aws_vpc.main]
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "dlg_private_net"
  }
}

resource "aws_route_table" "public" {
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "public route"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  depends_on = [aws_vpc.main, aws_internet_gateway.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "private route"
  }
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

resource "random_string" "pass" {
  length = 36
}

resource "aws_instance" "windows" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.private
  ]
  ami                         = "ami-079e6e7a0a7640784"
  instance_type               = "t3.small"
  key_name                    = var.ssh_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.local.id]
  get_password_data           = true
  user_data                   = file("./config/windows.ps1")
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted             = true
    delete_on_termination = true
  }
  # Prevents resource being recreated for minor versions of AMI 
  tags = {
    Name    = "dlg-windows"
    Purpose = "windows demo non-AD"
  }
}

resource "random_string" "token" {
  length = 32
}

resource "teleport_provision_token" "linux_jump" {
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
  vpc_security_group_ids = [aws_security_group.ssh.id]
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
  tags = {
    Name    = "dlg-windows-jump"
    Purpose = "windows demo non-AD"
  }
}
##################################################################################
# OUTPUT
##################################################################################
output "windows_public_dns" {
  value = aws_instance.windows.public_dns
}
output "windows_public_ip" {
  value = aws_instance.windows.public_ip
}
output "linux_public_ip" {
  value = aws_instance.linux_jump.public_ip
}
output "password_decrypted" {
  value = rsadecrypt(aws_instance.windows.password_data, file("~/.ssh/dlg-aws.pem"))
}
##################################################################################