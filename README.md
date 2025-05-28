# teleport_terraform: Reference Architecture for Teleport Resource Demos

This repository provides reusable Terraform modules and reference configurations for spinning up **Teleport self-hosted demos**, including:

- Linux/SSH node access
- Self-hosted MySQL/Postgres databases
- Windows infrastructure
- Applications like Grafana

Modules are built for **Solutions Engineers** to rapidly demo Teleport features using disposable infrastructure tied to their own clusters.

---

## Repository Layout

```
teleport_terraform/
├── modules/                     # Reusable infrastructure modules
│   ├── mysql_instance/         # MySQL + TLS + teleport.yaml bootstrap
│   ├── ssh_node/               # SSH EC2 nodes with dynamic labels
│   ├── windows_local/          # Windows EC2 join with agent
│   ├── app_grafana/            # Application access to Grafana
│   └── registration/           # teleport_* resources (db, app)
├── data_plane/                 # Use case implementations
│   ├── mysql_self/             # Matches Teleport MySQL docs
│   ├── ssh_getting_started/    # Matches SSH getting started docs
│   └── postgres_self/          # Planned
├── environments/               # Dev/prod/named envs to deploy stacks
│   ├── dev/
│   └── prod/
├── examples/                   # Minimal single-use examples
├── control_plane/              # (Optional) Cluster bootstrapping of Auth and Proxy services in various scenarios
└── README.md                   # This file
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Teleport CLI (tsh, tctl)](https://goteleport.com/download/)
- AWS credentials configured (via environment variables or AWS CLI)

---

## Usage Models

### 1. Full Environment Deployment

Use `environments/dev/` to spin up multiple services together:

```bash
cd environments/dev
terraform init
terraform apply
```

This uses:
- MySQL instance + dynamic DB registration
- SSH nodes with dynamic labels and role support

You can also duplicate the directory for `prod/`, `test/`, or cluster-specific names.

---

### 2. Isolated Use Case Demo

Run Terraform directly from a use case like `mysql_self` or `ssh_getting_started`:

```bash
cd data_plane/mysql_self
terraform init
terraform apply
```

Useful for:
- Reproducing docs
- Focused testing
- Individual module validation

---

## Labeling and Discovery Pattern

Resources use labels to support dynamic discovery and RBAC assignment:

```yaml
labels:
  tier: dev
  os: linux
```

Teleport agents advertise themselves, and `teleport.yaml` uses:

```yaml
resources:
  labels:
    match:
      - tier=dev
```

---

## Providing Inputs Securely

Supply credentials and configuration via environment variables (preferred) or a .tfvars file:

Example environment variables:

```hcl
export TF_VAR_user="dlg@example.com"
export TF_VAR_proxy_address="teleport.example.com"
export TF_VAR_teleport_version="17.4.8"
export TF_VAR_region="us-east-2"
export TF_VAR_env="dev"
```

Example `terraform.tfvars` file

```hcl
user             = "dlg@example.com"
proxy_address    = "teleport.example.com"
teleport_version = "17.4.8"
region           = "us-east-2"
env              = "dev"
```

Never commit a `.tfvars` file — instead use `.gitignore`:

```bash
echo "*.tfvars" >> .gitignore
```

Each use case includes `terraform.tfvars.example` for safe copy/paste.

---

## Available Modules

| Module              | Purpose                                     |
|---------------------|---------------------------------------------|
| `ssh_node`          | Linux SSH EC2 with labels and SSM-friendly  |
| `mysql_instance`    | TLS-enabled MySQL demo with dynamic registration   |
| `registration`      | Generic DB/App resource registration        |
| `windows_local`     | Non-AD Windows node join                    |
| `app_grafana`       | (Planned) Application access demo           |

---

## For Solutions Engineers

### Authenticate

```bash
tsh login --proxy=teleport.example.com --auth=example
export TELEPORT_ACCESS_TOKEN=$(tctl tokens add --type=bot)
eval $(tctl terraform env)
```

### 🚀 Deploy

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 📡 Verify

```bash
tsh ls --labels=tier=dev
```

### 🔁 Clean Up

```bash
terraform destroy
```

---

##  Contributing

Contributions welcome! Submit a PR or open an issue to:

- Add new resource modules (MongoDB, CloudSQL, etc.)
- Improve app demos (Grafana, Jenkins, Vault)
- Suggest workflows or CI for `terraform plan/apply`
