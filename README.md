# teleport_terraform: Reference Architecture for Teleport Resource Demos

This repository provides reusable Terraform modules and reference configurations for spinning up **Teleport self-hosted demos**, including:

- Linux/SSH node access
- Self-hosted MySQL/Postgres databases 
- Windows infrastructure
- Applications like Grafana
- Machine ID automation
- Desktop Access

Modules are built for **Solutions Engineers** to rapidly demo Teleport features using disposable infrastructure tied to their own clusters.

---

## Repository Layout

```
teleport_terraform/
├── modules/                     # Reusable infrastructure modules
│   ├── mysql_instance/         # MySQL + TLS + teleport.yaml bootstrap
│   ├── postgres_instance/      # PostgreSQL + TLS + certificate auth
│   ├── ssh_node/               # SSH EC2 nodes with dynamic labels
│   ├── windows_instance/       # Windows Desktop Access
│   ├── app_grafana/            # Application access to Grafana with JWT
│   ├── app_httpbin/            # HTTP testing applications
│   ├── machineid_ansible/      # Machine ID + Ansible automation
│   ├── network/                # VPC + security group templates
│   └── registration/           # teleport_* resources (db, app)
├── data_plane/                 # Use case implementations
│   ├── mysql_self/             # Based on [Database Access with Self-Hosted MySQL/MariaDB](https://goteleport.com/docs/enroll-resources/database-access/enroll-self-hosted-databases/mysql-self-hosted/)
│   ├── postgres_self/          # Based on [Database Access with Self-Hosted PostgreSQL](https://goteleport.com/docs/enroll-resources/database-access/enroll-self-hosted-databases/postgres-self-hosted/)
│   ├── ssh_getting_started/    # Based on [Server Access Getting Started Guide](https://goteleport.com/docs/enroll-resources/server-access/getting-started/)
│   ├── app_grafana/            # Based on [Protect a Web Application with Teleport](https://goteleport.com/docs/enroll-resources/application-access/getting-started/)
│   ├── app_httpbin/            # Simple HTTP app demo
│   ├── windows_local/          # Based on [Configure access for local Windows users](https://goteleport.com/docs/enroll-resources/desktop-access/getting-started/)
│   └── machineid_ansible/      # Based on [Machine ID with Ansible](https://goteleport.com/docs/enroll-resources/machine-id/access-guides/ansible/)
├── environments/               # Dev/prod/named envs to deploy stacks
│   ├── dev/                    # Complete development environment
│   └── prod/                   # Complete production environment
├── control_plane/              # Teleport cluster deployment options
│   ├── eks/                    # Kubernetes-based clusters
│   ├── linux/                  # Single-node clusters
│   └── linux_proxypeers/       # Proxy peering architecture
└── README.md                   # This file
```

---

## Prerequisites

- **[Terraform](https://developer.hashicorp.com/terraform/downloads)** >= 1.2.0
- **[Teleport CLI (tsh, tctl)](https://goteleport.com/download/)** 
- **AWS CLI** with configured credentials
- **Teleport Enterprise cluster** (existing or deploy via `control_plane/`)

---

## Quick Start

### 1. Configure AWS Credentials

```bash
# Option 1: AWS CLI (recommended)
aws configure

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-2"

# Verify access
aws sts get-caller-identity
```

### 2. Authenticate to Teleport

```bash
# Login to your cluster
tsh login --proxy=your-cluster.teleport.com

# Set up Terraform provider authentication
eval $(tctl terraform env)
```

### 3. Set Demo Environment Variables

**Use environment variables instead of .tfvars files** - this lets you quickly switch between demo scenarios without managing multiple configuration files:

```bash
# Core variables (set once)
export TF_VAR_user="your-email@company.com"
export TF_VAR_proxy_address="your-cluster.teleport.com"
export TF_VAR_teleport_version="17.5.2" 
export TF_VAR_region="us-east-2"

# Environment-specific (change as needed)
export TF_VAR_env="dev"        # or "prod", "staging", etc. (just reference it in your affiliated Teleport Roles)
```

### 4. Deploy Your Demo

```bash
# Individual use case
cd data_plane/mysql_self
terraform init && terraform apply

# Complete environment  
cd environments/dev
terraform init && terraform apply
```

### 5. Verify Resources

```bash
# Check registered resources
tsh ls --labels=tier=dev
tsh db ls
tsh apps ls

# Connect to resources
tsh ssh user@hostname 
tsh db connect mysql-dev --db-user=reader
tsh apps login grafana-dev
```

---

## Usage Models

### 1. Individual Use Case Demo

```bash
# Set your demo environment
export TF_VAR_env="dev"

# Deploy specific use case
cd data_plane/mysql_self
terraform init && terraform apply

# Demo database access
tsh db ls --labels=tier=dev
tsh db connect mysql-dev --db-user=reader
```

### 2. Complete Environment Demo

```bash
# Deploy full environment
cd environments/dev  
terraform init && terraform apply
```

**This deploys:**
- MySQL + PostgreSQL databases with TLS
- SSH nodes with dynamic labels
- Grafana application with JWT integration
- Windows Desktop Access
- All resources automatically registered with Teleport

---

## Environment Variable Configuration

### Why Environment Variables Over .tfvars Files?

**✅ Advantages:**
- **Quick environment switching** - change `TF_VAR_env` to switch demos
- **No file management** - no need to maintain multiple .tfvars files
- **Consistent across demos** - same variables work everywhere
- **Secure** - no risk of committing sensitive data

### Core Variables (Set Once)

```bash
# Your identity and cluster info
export TF_VAR_user="engineer@company.com"      # For resource tagging
export TF_VAR_proxy_address="cluster.teleport.com"  # Your Teleport cluster  
export TF_VAR_teleport_version="17.5.2"       # Teleport version to install
export TF_VAR_region="us-east-2"              # AWS region
```

### Demo-Specific Variables (Change As Needed)

> Note: See Labeling and Discovery Pattern for RBAC

```bash
# Switch environments easily
export TF_VAR_env="dev"           # Development demo
export TF_VAR_env="prod"          # Production demo  
```

### Advanced Variables (Optional)

```bash
# Customize deployments
export TF_VAR_agent_count="5"         # Number of SSH nodes
```

---

## Labeling and Discovery Pattern

Resources use consistent labels for dynamic discovery and RBAC:

```yaml
# Applied automatically to all resources
labels:
  tier: dev                         # From TF_VAR_env
```

**Teleport Role Integration:**
```yaml
# Example role using dynamic labels
allow:
  node_labels:
    tier: ["dev", "staging"]
  db_labels:
    tier: ["dev"]
  app_labels:
    tier: ["dev"]
```

**Label-based Resource Discovery:**
```bash
# List resources by environment
tsh ls --labels=tier=dev
tsh db ls --labels=tier=prod  
tsh apps ls --labels=tier=staging
```

---

## Available Modules

| Module | Purpose | Features |
|--------|---------|----------|
| **`ssh_node`** | Linux SSH access | Dynamic labels, enhanced recording, custom commands |
| **`mysql_instance`** | Self-hosted MySQL | TLS encryption, certificate auth, custom CA |
| **`postgres_instance`** | Self-hosted PostgreSQL | TLS encryption, certificate auth, custom users |
| **`windows_instance`** | Windows Desktop Access | RDP access, local user creation, domain joining |
| **`app_grafana`** | Grafana application | JWT integration, SSO, dashboard access |
| **`app_httpbin`** | HTTP testing app | Simple web application for testing |
| **`machineid_ansible`** | Machine ID automation | Bot authentication, Ansible playbooks |
| **`network`** | AWS networking | VPC, subnets, security groups, NAT gateway |
| **`registration`** | Resource registration | Generic teleport_database and teleport_app |

---

## Workflow

### Switching Between Demos

```bash
# Customer A demo
export TF_VAR_env="dev"
cd data_plane/mysql_self && terraform apply

# Customer B demo  
export TF_VAR_env="prod"
cd data_plane/postgres_self && terraform apply

# Full environment demo
export TF_VAR_env="dev"
cd environments/dev && terraform apply
```

### Demo Verification Commands

```bash
# Quick health check
terraform output                    # Show deployment outputs
tsh ls --labels=tier=$TF_VAR_env   # List SSH nodes
tsh db ls                          # List databases
tsh apps ls                        # List applications

# Demo connections
tsh ssh ubuntu@ssh-node            # SSH access
tsh db connect database-name       # Database access
tsh apps login app-name            # Application access
```

### Clean Up

```bash
# Clean up current demo
terraform destroy

# Or clean up specific environment
cd environments/dev && terraform destroy
```

---

## Troubleshooting

### Authentication Issues

```bash
# Verify AWS access
aws sts get-caller-identity

# Verify Teleport access  
tsh status
tctl status

# Re-authenticate if needed
eval $(tctl terraform env)
```

### Resource Registration Issues

```bash
# Check if resources are registered
tctl inventory ls

# Check agent connectivity
tsh ls --labels=tier=$TF_VAR_env
```

### Common Variables Issues

```bash
# Check your environment variables
env | grep TF_VAR

# Required variables check
echo "User: $TF_VAR_user"
echo "Proxy: $TF_VAR_proxy_address" 
echo "Version: $TF_VAR_teleport_version"
echo "Region: $TF_VAR_region"
echo "Env: $TF_VAR_env"
```

---

## Contributing

Contributions welcome! Submit a PR or open an issue to:

- **Add new resource modules** (MongoDB, Windows AD, Redis, etc.)
- **Improve application demos** (Jenkins, Vault, Kubernetes Dashboard)
- **Enhance automation** (CI/CD workflows, testing frameworks)
- **Expand documentation** (runbooks, troubleshooting guides)

---

## Advanced Usage

### Control Plane Deployment

Deploy your own Teleport clusters:

```bash
# EKS-based cluster
cd control_plane/eks/1-eks-cluster && terraform apply
cd control_plane/eks/2-kubernetes-config && terraform apply

# Single-node Linux cluster
cd control_plane/linux && terraform apply

# Proxy peering architecture
cd control_plane/linux_proxypeers && terraform apply
```

### Custom Module Development

Follow the established patterns:

```hcl
# modules/your_module/main.tf
terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
    teleport = { source = "terraform.releases.teleport.dev/gravitational/teleport" }
  }
}

# Use consistent variable names
variable "env" { }
variable "user" { }
variable "proxy_address" { }
variable "teleport_version" { }
```