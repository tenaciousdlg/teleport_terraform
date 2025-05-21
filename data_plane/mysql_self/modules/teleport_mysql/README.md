# 🚀 Teleport MySQL Self-Hosted Module

This Terraform module provisions a self-hosted MySQL server on AWS and registers it with a [Teleport](https://goteleport.com) cluster using the Teleport Terraform provider. It's built for internal training, demos, and self-contained testing environments.

## 🔧 What It Does

- Provisions an EC2 instance running MariaDB (MySQL-compatible)
- Sets up TLS encryption with a self-signed certificate
- Configures Teleport Database Service with dynamic discovery via label matching
- Registers the MySQL instance as a `teleport_database` resource via Terraform
- Uses a short-lived provision token to bootstrap access

---

## 📁 Directory Structure

modules/teleport_mysql/
├── main.tf # EC2 + Teleport DB + TLS + Terraform resources
├── variables.tf # Configurable inputs (region, version, etc.)
├── outputs.tf # (optional) Resource outputs
└── userdata.tpl # Instance bootstrap script for MySQL + Teleport agent

---

## 📥 Inputs

| Variable             | Description                                    | Example                  |
|----------------------|------------------------------------------------|--------------------------|
| `env`                | Environment name (`dev`, `prod`, etc.)         | `dev`                    |
| `user`               | Tagging/user label for internal tracking       | `jsmith`                  |
| `proxy_address`      | Teleport Proxy (no scheme)                     | `proxy.example.com`|
| `teleport_version`   | Teleport version (major or full)               | `17.0.0`                 |
| `teleport_db_ca`     | CA cert fetched from proxy `/webapi/auth/export` | Pulled via `data.http` |
| `mysql_hostname`     | Internal hostname for MySQL                    | `mysql.dev.internal`     |
| `ami_id`             | Ubuntu 22.04 AMI ID                            | Dynamic via `data.aws_ami` |
| `instance_type`      | EC2 instance type                              | `t3.small`               |
| `subnet_id`          | Subnet to launch instance into                | -                        |
| `security_group_ids` | List of security groups for the instance       | `["sg-abc123"]`          |

---

## 🚀 Example Usage

```hcl
module "mysql_dev" {
  source = "./modules/teleport_mysql"

  env               = "dev"
  user              = "demo-user"
  proxy_address     = "proxy.teleportdemo.com"
  teleport_version  = "16.0.0"
  teleport_db_ca    = data.http.teleport_db_ca_cert.response_body

  mysql_hostname    = "mysql.dev.internal"
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = "t3.small"
  subnet_id         = aws_subnet.main.id
  security_group_ids = [aws_security_group.main.id]
}
