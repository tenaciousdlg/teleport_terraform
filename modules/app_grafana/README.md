# Grafana Application Module

Creates a containerized Grafana instance with Teleport application access and JWT authentication for demonstrating application access capabilities.

## Overview

- **Use Case:** Application access with JWT authentication
- **Teleport Features:** App access, JWT tokens, SSO integration, application session recording
- **Infrastructure:** EC2 instance with Docker, Grafana container, and Teleport agent

## Usage

```hcl
module "grafana_app" {
  source = "../../modules/app_grafana"
  
  env              = "dev"
  user             = "engineer@company.com"
  proxy_address    = "teleport.company.com"
  teleport_version = "17.5.2"
  
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.small"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}
```

## What It Creates

### AWS Resources
- **EC2 Instance:** Amazon Linux 2023 with Docker
- **Grafana Container:** Latest Grafana with JWT authentication configured

### Teleport Resources
- **Provision Token:** For application and SSH service registration
- **Application Service:** Configured to discover applications with `teleport.dev/app=grafana` label

### Teleport Services Enabled
- ** Application Service:** Grafana web application access with JWT auth  
- ** SSH Service:** Server management and troubleshooting access

## Label Structure & Access Control

This module applies consistent labels for RBAC and dynamic discovery:

```yaml
Labels Applied:
  tier: "dev"                    # From var.env - environment-based access
  team: "engineering"            # From var.team - team-based access
  "teleport.dev/app": "grafana"  # Application discovery label
```

### RBAC Integration
```yaml
# Example Teleport role using these labels:
allow:
  app_labels:
    tier: ["dev", "staging"]     # Access dev and staging apps
    team: ["engineering"]        # Only engineering team
    "teleport.dev/app": ["grafana", "kibana"]  # Specific apps
  node_labels:
    tier: ["dev"]                # SSH access to dev servers
    team: ["engineering"]        # Same team restriction
```

### Customization
To adapt for your environment, modify the labels in your configuration to correspond to your labels in Roles:
```hcl
# Custom labels for your organization
labels = {
  tier               = "production"   # or "dev", "staging", "qa"
  team               = "platform"     # or "frontend", "backend", "data"
  "teleport.dev/app" = "grafana"      # Keep for service discovery
  owner              = "sre-team"     # Add ownership info
  criticality        = "high"         # Add business criticality
}
```

## Demo Commands

### Application Access
```bash
# List applications
tsh apps ls --labels=tier=dev

# Login to Grafana application
tsh apps login grafana-dev

# Access Grafana (opens in browser)
tsh apps config grafana-dev
```

### SSH Access (Server Management)
```bash
# List SSH nodes
tsh ls --labels=tier=dev

# SSH into the Grafana server
tsh ssh ec2-user@dev-grafana

# Check Grafana container status
docker ps
docker logs grafana

# Check Teleport app service
sudo systemctl status teleport
```

## Grafana Configuration

### JWT Authentication
- **Header:** `Teleport-Jwt-Assertion`
- **JWKS URL:** `https://{proxy_address}/.well-known/jwks.json`
- **Auto Sign-up:** Enabled
- **Email Claim:** `sub`
- **Username Claim:** `sub`

### Access URL
- **Internal:** `http://localhost:3000`
- **External:** `https://grafana-{env}.{proxy_address}`

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `env` | Environment name | `string` | - |
| `user` | Creator tag | `string` | - |
| `proxy_address` | Teleport proxy address | `string` | - |
| `teleport_version` | Teleport version to install | `string` | - |
| `ami_id` | AMI ID for instance | `string` | - |
| `instance_type` | EC2 instance type | `string` | - |
| `subnet_id` | Subnet for instance | `string` | - |
| `security_group_ids` | Security group IDs | `list(string)` | - |
| `team` | Team label | `string` | `"engineering"` |

## Outputs

| Output | Description |
|--------|-------------|
| `grafana_private_ip` | Private IP address of Grafana instance |

## Integration

This module works with the `registration` module for dynamic discovery:

```hcl
module "grafana_registration" {
  source        = "../../modules/registration"
  resource_type = "app"
  name          = "grafana-${var.env}"
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
```

## Features

- **JWT Authentication:** Seamless SSO via Teleport
- **Automatic User Creation:** Users auto-provisioned on first access
- **Session Recording:** All application interactions recorded
- **Dynamic Discovery:** Automatically registered via labels
- **Header Rewriting:** Proper host headers for sub-domain access

## Troubleshooting

### Multiple Services Status
This instance runs both application and SSH services. Check both when troubleshooting:

```bash
# SSH into the server first
tsh ssh ec2-user@dev-grafana

# Check all Teleport services
sudo systemctl status teleport
sudo journalctl -u teleport -f

# Check Grafana container
docker ps
docker logs grafana

# Test internal Grafana access
curl -k http://localhost:3000

# Check application service specifically
tctl apps ls
tsh apps ls --debug
```

### Common Issues
- **JWT Verification Failed:** Check JWKS URL accessibility from Grafana container
- **Login Loop:** Verify header rewriting configuration in registration module
- **Access Denied:** Check user roles and application permissions
- **SSH Access Issues:** Verify user roles and node labels
- **Container Issues:** Check Docker daemon and Grafana container health

### Service-Specific Debugging
```bash
# Application service issues
tsh apps login grafana-dev --debug
tctl tokens ls  # Check token validity

# SSH service issues
tsh ssh ec2-user@dev-grafana --debug  
tctl nodes ls

# Grafana container issues
docker exec -it grafana /bin/bash
cat /etc/grafana/grafana.ini

# Network connectivity
curl -v https://proxy.address/.well-known/jwks.json
```