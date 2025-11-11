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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

data "http" "teleport_db_ca_cert" {
  url = "https://${var.proxy_address}/webapi/auth/export?type=db-client"
}

data "aws_ami" "windows_server" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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

# =============================================================================
# NETWORKING
# =============================================================================
module "network" {
  source                  = "../../modules/network"
  cidr_vpc                = "10.0.0.0/16"
  cidr_subnet             = "10.0.1.0/24"
  cidr_public_subnet      = "10.0.0.0/24"
  env                     = var.env
  create_secondary_subnet = true
  cidr_secondary_subnet   = "10.0.2.0/24"
  create_db_subnet_group  = true
}

# =============================================================================
# DATABASE RESOURCES
# =============================================================================

# MySQL Self-Hosted Database
module "mysql_instance" {
  source             = "../../modules/mysql_instance"
  env                = var.env
  user               = var.user
  team               = var.team
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  teleport_db_ca     = data.http.teleport_db_ca_cert.response_body
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "mysql_registration" {
  source        = "../../modules/registration"
  resource_type = "database"
  name          = "mysql-${var.env}"
  description   = "Self-hosted MySQL database in ${var.env}"
  protocol      = "mysql"
  uri           = "localhost:3306"
  ca_cert_chain = module.mysql_instance.ca_cert
  labels = {
    tier = var.env
    team = var.team
  }
}

# PostgreSQL Self-Hosted Database
module "postgres_instance" {
  source             = "../../modules/postgres_instance"
  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  teleport_db_ca     = data.http.teleport_db_ca_cert.response_body
  postgres_hostname  = "postgres.dev.internal"
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "postgres_registration" {
  source        = "../../modules/registration"
  resource_type = "database"
  name          = "postgres-${var.env}"
  description   = "Self-hosted PostgreSQL database in ${var.env}"
  protocol      = "postgres"
  uri           = "localhost:5432"
  ca_cert_chain = module.postgres_instance.ca_cert
  labels = {
    tier = var.env
    team = var.team
  }
}

# MongoDB Self-Hosted Database (NEW)
module "mongodb_instance" {
  source             = "../../modules/mongodb_instance"
  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  teleport_db_ca     = data.http.teleport_db_ca_cert.response_body
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "mongodb_registration" {
  source        = "../../modules/registration"
  resource_type = "database"
  name          = "mongodb-${var.env}"
  description   = "Self-hosted MongoDB database in ${var.env}"
  protocol      = "mongodb"
  uri           = "localhost:27017"
  ca_cert_chain = module.mongodb_instance.ca_cert
  labels = {
    tier = var.env
    team = var.team
  }
}

# RDS MySQL with Auto User Provisioning (NEW)
module "rds_mysql" {
  source = "../../modules/rds_mysql"

  env                  = var.env
  team                 = var.team
  user                 = var.user
  proxy_address        = var.proxy_address
  teleport_version     = var.teleport_version
  region               = var.region
  vpc_id               = module.network.vpc_id
  db_subnet_group_name = module.network.db_subnet_group_name
  subnet_id            = module.network.subnet_id
  security_group_ids   = [module.network.security_group_id]
  ami_id               = data.aws_ami.linux.id
}

# =============================================================================
# SSH RESOURCES
# =============================================================================
module "ssh_nodes" {
  source             = "../../modules/ssh_node"
  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  agent_count        = 3 # Deploy multiple nodes for demo
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.micro"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

# =============================================================================
# WINDOWS DESKTOP ACCESS
# =============================================================================
module "windows_instance" {
  source             = "../../modules/windows_instance"
  env                = var.env
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  ami_id             = data.aws_ami.windows_server.id
  instance_type      = "t3.medium"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "linux_desktop_service" {
  source               = "../../modules/linux_desktop_service"
  env                  = var.env
  team                 = var.team
  user                 = var.user
  proxy_address        = var.proxy_address
  teleport_version     = var.teleport_version
  ami_id               = data.aws_ami.linux.id
  instance_type        = "t3.small"
  subnet_id            = module.network.subnet_id
  security_group_ids   = [module.network.security_group_id]
  windows_internal_dns = module.windows_instance.private_dns
  windows_hosts = [
    {
      name    = module.windows_instance.hostname
      address = "${module.windows_instance.private_ip}:3389"
    }
  ]
}

# =============================================================================
# APPLICATION ACCESS
# =============================================================================
module "grafana_app" {
  source             = "../../modules/app_grafana"
  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "grafana_registration" {
  source        = "../../modules/registration"
  resource_type = "app"
  name          = "grafana-${var.env}"
  description   = "Grafana dashboard for ${var.env} environment"
  uri           = "http://localhost:3000"
  public_addr   = "grafana-${var.env}.${var.proxy_address}"
  labels = {
    tier               = var.env
    team               = var.team
    "teleport.dev/app" = "grafana"
  }
  rewrite_headers = [
    "Host: grafana-${var.env}.${var.proxy_address}",
    "Origin: https://grafana-${var.env}.${var.proxy_address}"
  ]
  insecure_skip_verify = true
}

# HTTPBin Application (NEW)
module "httpbin_app" {
  source             = "../../modules/app_httpbin"
  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.micro"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

module "httpbin_registration" {
  source        = "../../modules/registration"
  resource_type = "app"
  name          = "httpbin-${var.env}"
  description   = "HTTP testing application for ${var.env}"
  uri           = "http://localhost:80"
  public_addr   = "httpbin-${var.env}.${var.proxy_address}"
  labels = {
    tier               = var.env
    team               = var.team
    "teleport.dev/app" = "httpbin"
  }
  rewrite_headers = [
    "Host: httpbin-${var.env}.${var.proxy_address}",
    "Origin: https://httpbin-${var.env}.${var.proxy_address}"
  ]
  insecure_skip_verify = true
}

# =============================================================================
# MACHINE ID / AUTOMATION
# =============================================================================
module "machineid_ansible" {
  source = "../../modules/machineid_ansible"

  env                = var.env
  team               = var.team
  user               = var.user
  proxy_address      = var.proxy_address
  teleport_version   = var.teleport_version
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}

# =============================================================================
# OUTPUTS
# =============================================================================
output "demo_resources" {
  description = "Summary of deployed demo resources"
  value = {
    # Databases
    mysql_endpoint     = "mysql-${var.env}"
    postgres_endpoint  = "postgres-${var.env}"
    mongodb_endpoint   = "mongodb-${var.env}"
    rds_mysql_endpoint = module.rds_mysql.database_name

    # Applications
    grafana_url = "https://grafana-${var.env}.${var.proxy_address}"
    httpbin_url = "https://httpbin-${var.env}.${var.proxy_address}"

    # Windows Desktop
    windows_desktop = module.windows_instance.hostname

    # Machine ID
    ansible_host = "Ansible automation configured with Machine ID"

    # SSH Nodes
    ssh_node_count = 3
  }
}

output "verification_commands" {
  description = "Commands to verify the demo deployment"
  value = {
    list_resources = {
      ssh_nodes = "tsh ls --labels=tier=${var.env}"
      databases = "tsh db ls --labels=tier=${var.env}"
      apps      = "tsh apps ls --labels=tier=${var.env}"
      desktops  = "tsh desktops ls --labels=tier=${var.env}"
    }

    demo_connections = {
      ssh_access      = "tsh ssh ec2-user@${var.env}-ssh-0"
      mysql_access    = "tsh db connect mysql-${var.env} --db-user=reader"
      postgres_access = "tsh db connect postgres-${var.env} --db-user=reader"
      mongodb_access  = "tsh db connect mongodb-${var.env} --db-user=reader"
      rds_mysql       = "tsh db connect ${module.rds_mysql.database_name}"
      grafana_access  = "tsh apps login grafana-${var.env}"
      httpbin_access  = "tsh apps login httpbin-${var.env}"
    }
  }
}

output "role_based_access_demo" {
  description = "Commands to demonstrate role-based access controls"
  value = {
    dev_role_demo = [
      "# Users with dev-access role can access:",
      "tsh ls --labels=tier=dev",
      "tsh db ls --labels=tier=dev",
      "tsh apps ls --labels=tier=dev"
    ]

    prod_role_demo = [
      "# Users with prod-access role need approval for prod resources",
      "# But can access dev resources directly"
    ]

    request_access = [
      "# Request elevated access:",
      "tsh request create --roles=prod-access --reason='Customer demo'"
    ]
  }
}