# Teleport MySQL Module

This repository provides reusable Terraform modules to deploy and register a MySQL database with Teleport. It provisions a self-hosted MySQL instance on AWS EC2, configures Teleport's Database Service dynamically, and registers the database using the Teleport Terraform provider.

---

## 📦 Modules

### `teleport_mysql_instance`
Provision and configure:
- EC2 instance (Ubuntu 22.04)
- MySQL with TLS (MariaDB)
- Teleport Database Service with dynamic resource discovery
- CA + server certificates

#### Inputs
| Name                 | Description                                                     |
|----------------------|-----------------------------------------------------------------|
| `env`               | Environment name (e.g., `dev`, `prod`)                          |
| `user`              | Creator label for tagging AWS resources                        |
| `proxy_address`     | Teleport Proxy host (without protocol)                         |
| `teleport_version`  | Teleport version to install (e.g., `16.0.0`)                   |
| `teleport_db_ca`    | Teleport DB CA from `/webapi/auth/export`                      |
| `mysql_hostname`    | (Optional) FQDN of MySQL instance, used in TLS cert CN         |
| `ami_id`            | Ubuntu AMI ID                                                   |
| `instance_type`     | EC2 instance type (e.g., `t3.small`)                           |
| `subnet_id`         | Subnet for the instance                                         |
| `security_group_ids`| List of security group IDs                                      |

#### Outputs
| Name              | Description                         |
|-------------------|-------------------------------------|
| `ca_cert`         | Internal CA cert used for MySQL     |
| `teleport_db_ca`  | Teleport DB CA (as passed in)       |
| `instance_ip`     | Public IP of the MySQL EC2 instance |

---

### `teleport_mysql_registration`

Register the database with Teleport using `teleport_database` resource.

#### Inputs
| Name              | Description                                           |
|-------------------|-------------------------------------------------------|
| `env`            | Environment name (`dev`, `prod`, etc.)               |
| `name`           | Logical DB name (default: `mysql`)                   |
| `uri`            | DB endpoint URI (e.g., `localhost:3306`)             |
| `ca_cert_chain`  | Combined PEM for Teleport to verify MySQL TLS        |
| `labels`         | Custom labels applied to the DB resource             |

#### Outputs
| Name     | Description             |
|----------|-------------------------|
| `db_name`| Name of the DB resource |

---

## 🚀 Usage Example
In `environments/dev/main.tf`:

```hcl
module "mysql_instance" {
  source              = "../../modules/teleport_mysql_instance"
  env                 = var.env
  user                = var.user
  proxy_address       = var.proxy_address
  teleport_version    = var.teleport_version
  teleport_db_ca      = data.http.teleport_db_ca_cert.response_body
  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = "t3.small"
  subnet_id           = var.subnet_id
  security_group_ids  = [var.security_group_id]
}

module "mysql_registration" {
  source          = "../../modules/teleport_mysql_registration"
  env             = var.env
  uri             = "localhost:3306"
  ca_cert_chain   = module.mysql_instance.ca_cert
  labels = {
    tier = var.env
  }
}
```

---

## 🔐 Notes
- `teleport.yaml` on the EC2 instance uses dynamic discovery via `resources.labels.match`.
- TLS certs are generated and provisioned via Terraform.
- User `alice` has full access; user `bob` has limited view/read permissions via cert CN.

---

## 📄 Requirements
- Terraform ≥ 1.3
- Teleport Enterprise ≥ 14.0 (for dynamic DB registration)
- AWS CLI + credentials setup for Terraform to access

---

## 📁 Environments
Use separate `terraform.tfvars` and `main.tf` under `environments/<env>` for each deployment:

```
environments/
├── dev/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── prod/
│   └── ...
```

---

## 📬 Support
Feel free to open an issue or reach out if you'd like to add:
- RDS or GCP CloudSQL support
- SSM Parameter output for secrets
- CI/CD example for plan/apply
