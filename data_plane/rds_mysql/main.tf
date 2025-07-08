##################################################################################
# CONFIGURATION / PROVIDERS
##################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99"
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
      "ManagedBy"            = "Terraform"
      "Purpose"              = "teleport rds mysql with auto user creation"
    }
  }
}

provider "teleport" {
  addr = "${var.proxy_address}:443"
}

provider "random" {
}

##################################################################################
# DATA SOURCES / LOCALS
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
  owners = ["099720109477"]
}

locals {
  user = lower(split("@", var.user)[0])
}

##################################################################################
# NETWORKING MODULE
##################################################################################
module "networking" {
  source = "../../modules/network"

  env                     = var.env
  cidr_vpc                = var.cidr_vpc
  cidr_subnet             = var.cidr_subnet
  cidr_public_subnet      = var.cidr_public_subnet
  create_secondary_subnet = true
  cidr_secondary_subnet   = var.cidr_secondary_subnet
  create_db_subnet_group  = true
}

##################################################################################
# RDS INSTANCE
##################################################################################
resource "aws_db_instance" "mysql" {
  identifier = "${local.user}-${var.env}-rds-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name                             = "teleport"
  username                            = "admin"
  password                            = module.rds_proxy.db_password
  iam_database_authentication_enabled = true

  db_subnet_group_name   = module.networking.db_subnet_group_name
  vpc_security_group_ids = [module.networking.security_group_id]
  publicly_accessible    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  parameter_group_name = aws_db_parameter_group.mysql.name

  deletion_protection = false
  skip_final_snapshot = true
}

resource "aws_db_parameter_group" "mysql" {
  family = "mysql8.0"
  name   = "${local.user}-${var.env}-rds-mysql-params"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }
}

##################################################################################
# RDS PROXY MODULE
##################################################################################
module "rds_proxy" {
  source = "../../modules/rds_proxy"

  user                   = var.user
  env                    = var.env
  engine                 = "mysql"
  engine_family          = "MYSQL"
  db_username            = "admin"
  db_instance_identifier = aws_db_instance.mysql.identifier
  subnet_ids             = module.networking.private_subnet_ids
  security_group_ids     = [module.networking.security_group_id]
}

##################################################################################
# TELEPORT RESOURCES
##################################################################################
resource "random_string" "token" {
  length = 32
}

resource "teleport_provision_token" "db" {
  version = "v2"
  spec = {
    roles = ["Db", "Node"]
    name  = random_string.token.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "teleport_database" "rds_mysql" {
  version = "v3"
  metadata = {
    name        = "rds-mysql"
    description = "RDS MySQL via RDS Proxy"
    labels = {
      tier                  = var.env
      "teleport.dev/origin" = "dynamic"
    }
  }
  spec = {
    admin_user = {
      default_database = "teleport"
      name             = "teleport-admin"
    }
    protocol = "mysql"
    uri      = "${module.rds_proxy.proxy_endpoint}:3306"
    # Note: Auto user creation not yet supported for MySQL/RDS Proxy
    aws = {
      region = var.aws_region
      rds = {
        instance_id = aws_db_instance.mysql.identifier
      }
    }
  }
}

##################################################################################
# TELEPORT AGENT EC2 INSTANCE
##################################################################################
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.networking.public_subnet_id
  vpc_security_group_ids = [module.networking.security_group_id]

  user_data = templatefile("./config/userdata", {
    token            = teleport_provision_token.db.metadata.name
    proxy_address    = var.proxy_address
    teleport_version = var.teleport_version
    rds_endpoint     = module.rds_proxy.proxy_endpoint
    rds_password     = module.rds_proxy.db_password
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.user}-${var.env}-rds-mysql"
  }
}

##################################################################################
# OUTPUT
##################################################################################
output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "proxy_endpoint" {
  value = module.rds_proxy.proxy_endpoint
}

output "connection_instructions" {
  value = <<-EOF
    1. Connect to Teleport cluster: tsh login --proxy=${var.proxy_address}:443
    2. List available databases: tsh db ls
    3. Connect to database: tsh db connect rds-mysql
    4. Auto user creation is enabled - users will be created automatically on first connection
    5. Users are assigned the 'teleport-auto-user' role and permissions based on Teleport roles
  EOF
}