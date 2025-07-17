# Windows Instance Module

Creates a Windows Server instance with Teleport certificate authentication for demonstrating Windows Desktop Access capabilities.

## Overview

- **Use Case:** Windows Desktop Access demonstration
- **Teleport Features:** Desktop access, RDP over Teleport, session recording, certificate authentication
- **Infrastructure:** Windows Server 2022 EC2 instance with Teleport certificate installed

## Usage

```hcl
module "windows_instance" {
  source = "../../modules/windows_instance"
  
  env              = "dev"
  user             = "engineer@company.com"
  proxy_address    = "teleport.company.com"
  teleport_version = "17.5.2"
  
  ami_id             = data.aws_ami.windows_server.id
  instance_type      = "t3.medium"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}
```

## What It Creates

### AWS Resources
- **EC2 Instance:** Windows Server 2022 with Teleport certificate
- **Local User:** Created with administrative privileges
- **Auto-restart:** Instance renames itself and restarts for domain preparation

### Teleport Resources
- **Certificate Download:** Teleport Windows certificate installed from proxy
- **Computer Rename:** Computer renamed to `{env}-desktop` pattern

### Windows Configuration
- **RDP Target:** Prepared for Desktop Service connection
- **Local User:** Administrator user created with complex password
- **Certificate Auth:** Teleport certificate installed for authentication via Smart Card Emulation on Windows

## Label Structure & Access Control

This instance is typically accessed through the `linux_desktop_service` module, which applies labels:

```yaml
Labels Applied (via Desktop Service):
  tier: "dev"          # From var.env - environment-based access
  team: "engineering"  # From var.team - team-based access
```

### RBAC Integration
```yaml
# Example Teleport role for desktop access:
allow:
  windows_desktop_labels:
    tier: ["dev", "staging"]     # Access dev and staging desktops
    team: ["engineering"]        # Only engineering team
  windows_desktop_logins: ["Administrator", "{{email.local(external.username)}}"]
```

### Customization
Desktop access permissions are typically configured in the Desktop Service:
```hcl
# Custom labels for your organization  
windows_desktop_labels = {
  tier        = "production"     # or "dev", "staging", "qa"
  team        = "platform"       # or "frontend", "backend", "data"
  region      = "us-west-2"      # Add region-specific access
  compliance  = "iso27001"       # Add compliance requirements
}
```

## Demo Commands

### Desktop Access (via Desktop Service)
Achieved through Teleport UI or [Teleport Connect](https://goteleport.com/docs/connect-your-client/teleport-connect/#installation--upgrade)

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `env` | Environment tag | `string` | - |
| `user` | Creator tag (used for local username) | `string` | - |
| `proxy_address` | Teleport proxy address | `string` | - |
| `teleport_version` | Teleport version (for certificate download) | `string` | - |
| `ami_id` | Windows Server AMI ID | `string` | - |
| `instance_type` | EC2 instance type | `string` | `"t3.medium"` |
| `subnet_id` | Subnet for instance | `string` | - |
| `security_group_ids` | Security group IDs | `list(string)` | - |

## Outputs

| Output | Description |
|--------|-------------|
| `private_ip` | Private IP address of Windows instance |
| `private_dns` | Private DNS name of Windows instance |
| `hostname` | Computer hostname after rename |

## Windows Configuration Details

### User Setup
```powershell
# User created during initialization:
Username: {user}                    # Derived from var.user (email prefix)
Password: {random-40-char-string}   # Auto-generated secure password
Groups: Administrators, Remote Desktop Users
```

### Certificate Installation
```powershell
# Certificate download and installation:
Source: https://{proxy_address}/webapi/auth/export?type=windows
Location: C:\temp\teleport.cer
Action: Installed for Windows Desktop Access authentication
```

### Computer Configuration
```powershell
# Computer renamed for consistency:
Original: Random EC2 name
New Name: {env}-desktop
Action: Automatic restart after rename
```

## Integration

This module is designed to work with the `linux_desktop_service` module:

```hcl
# First create Windows instance
module "windows_instance" {
  source = "../../modules/windows_instance"
  # ... configuration
}

# Then create Desktop Service pointing to Windows instance
module "linux_desktop_service" {
  source               = "../../modules/linux_desktop_service"
  windows_internal_dns = module.windows_instance.private_dns
  windows_hosts = [
    {
      name    = module.windows_instance.hostname
      address = "${module.windows_instance.private_ip}:3389"
    }
  ]
  # ... other configuration
}
```

## Security Features

- **Certificate Authentication:** Uses Teleport certificate for secure authentication
- **Complex Passwords:** Auto-generated 40-character passwords
- **Administrative Access:** Created user has full administrative privileges
- **Network Isolation:** Deployed in private subnet, accessed via Desktop Service
- **Session Recording:** All desktop interactions recorded via Teleport
- **Encrypted Transport:** RDP traffic encrypted through Teleport tunnel

## Troubleshooting

### Windows Instance Status
This instance serves as an RDP target and doesn't run Teleport agent directly:

```bash
# Check Desktop Service logs (on Linux Desktop Service instance)
tsh ssh ec2-user@dev-desktop-service
sudo journalctl -u teleport -f
```

### Common Issues
- **Desktop Not Listed:** Check Desktop Service configuration and registration
- **Connection Failed:** Verify Windows instance is running and accessible
- **Authentication Failed:** Check certificate installation and user creation
- **RDP Port Blocked:** Ensure security groups allow port 3389 from Desktop Service
- **Instance Not Ready:** Windows initialization takes 5-10 minutes after launch

### Debug Commands
```bash
# Check Windows instance status
aws ec2 describe-instances --instance-ids {instance-id}

# Test network connectivity to Windows instance
tsh ssh ec2-user@dev-desktop-service
ping {windows-private-ip}
nc -zv {windows-private-ip} 3389

# Check Desktop Service configuration
tctl get windows_desktop/{hostname}
tctl status
```

### Windows-Specific Debugging
```powershell
# Connect to Windows instance via RDP to check configuration
# Check if certificate is installed
Get-ChildItem -Path Cert:\LocalMachine\My

# Check Windows Event Logs
Get-EventLog -LogName System -Newest 50
Get-EventLog -LogName Application -Newest 50

# Verify RDP is enabled
Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections"

# Check user creation
Get-LocalUser
Get-LocalGroupMember -Group "Administrators"
```

## Performance Considerations

- **Instance Size:** t3.medium minimum recommended for responsive desktop experience
- **Network Latency:** Desktop performance depends on network latency to AWS region
- **Concurrent Sessions:** Windows Server supports multiple concurrent RDP sessions
- **Resource Usage:** Desktop applications consume memory and CPU on Windows instance

## Instance Sizing Guidelines

| Instance Type | vCPU | RAM | Use Case |
|---------------|------|-----|----------|
| `t3.medium` | 2 | 4GB | Basic demos, single user |
| `t3.large` | 2 | 8GB | Multiple concurrent users |
| `t3.xlarge` | 4 | 16GB | Heavy applications, development |
| `m5.large` | 2 | 8GB | Production demos, better network |

## Features

- **Automatic Setup:** Complete unattended installation and configuration
- **Certificate Integration:** Seamless integration with Teleport authentication
- **Session Recording:** Complete desktop session audit trail
- **Network Security:** Accessed only through Teleport Desktop Service
- **Scalable:** Can create multiple instances for different environments
- **Cost Optimized:** Uses Windows Server Base edition

## Advanced Configuration

### Custom User Setup
```hcl
# Modify userdata template for custom user configuration
variable "admin_users" {
  description = "List of admin users to create"
  type        = list(string)
  default     = []
}
```

### Domain Integration
```powershell
# For domain-joined scenarios (requires additional configuration)
# Add domain join commands to userdata template
Add-Computer -DomainName "your-domain.com" -Credential $credential -Restart
```

### Application Pre-installation
```powershell
# Add application installation to userdata
# Install applications via Chocolatey or direct download
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install googlechrome firefox notepadplusplus -y
```