# Teleport Demo Environment - EKS Deployment for Solutions Engineers

> ⚠️ **Demo Environment**: Optimized for SE demonstrations and rapid updates. Not for production use.

This repository provides an improved workflow for managing Teleport demo environments that eliminates manual coordination, enables 2-3 minute updates, and fixes common CRD management issues.

![Demo Environment](https://img.shields.io/badge/Purpose-Demo%20Environment-yellow)
![Cost Optimized](https://img.shields.io/badge/Cost-~$180%2Fmonth-green)
![Update Time](https://img.shields.io/badge/Updates-2--3%20minutes-blue)

## 🔗 Quick Links
- [Cost Profile](#-cost-profile) - ~$180/month optimized deployment
- [Fast Updates](#-fast-update-workflow) - 2-3 minute version changes
- [Troubleshooting](#-troubleshooting) - Common issues and solutions
- [What's Excluded](#-intentionally-omitted-cost-savings) - Cost-saving decisions

## 🎯 Key Benefits

### ✅ **Problems Solved**
- **No Manual Coordination**: Automatic provider configuration via remote state
- **Fast Updates**: Update Teleport in 2-3 minutes without touching EKS infrastructure  
- **Safe Rollbacks**: Easy rollback capability without affecting the underlying cluster
- **Consolidated Configuration**: All resources managed in Terraform with proper dependencies
- **CRD Management**: Reliable CRD handling prevents deletion issues during updates

### 🏗️ **Architecture**

```
📁 1-eks-cluster/          # EKS Infrastructure (stable, rarely changed)
├── main.tf                # VPC, EKS cluster, node groups, addons
├── outputs.tf             # Cluster info for remote state sharing
├── variables.tf           # Infrastructure variables
└── terraform.tfvars       # Your infrastructure configuration

📁 2-kubernetes-config/    # Teleport Deployment (frequently updated)
├── main.tf                # Complete Teleport deployment + operator resources
├── variables.tf           # Teleport configuration variables  
├── terraform.tfvars       # Your Teleport configuration
├── demo-apps.tf           # Demo applications for testing access
└── license.pem            # Enterprise license (optional)

📄 update-teleport.sh      # Fast update management script
```
## 💰 Cost Profile

This demo environment is optimized for cost (~$160-180/month):
- Single NAT Gateway (saves $90/month vs multi-AZ)
- SPOT instances for workers (saves 70% vs on-demand)
- No high availability replicas
- DynamoDB on-demand billing

For comparison, a production-grade deployment would cost $400-500/month.

## 🚀 Quick Start

### Prerequisites

- **Terraform** v1.3+
- **AWS CLI** v2.0+ (configured with credentials)
- **kubectl** v1.25+
- **Helm** v3.0+
- **Valid Teleport license** (place in `2-kubernetes-config/license.pem`)
- **Route53 hosted zone** (optional, for DNS management)
- **Okta account** with SAML app configured

### 1. Initial Setup

```bash
# Clone and navigate to the EKS directory
git clone <your-repo>
cd teleport-demo/

# Validate your environment
aws sts get-caller-identity
terraform --version
```

### 2. Configure Infrastructure

```bash
# Configure EKS cluster
cd 1-eks-cluster
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Deploy EKS infrastructure (one-time setup)
terraform init
terraform apply
```

### 3. Configure Teleport

```bash
# Configure Teleport deployment
cd ../2-kubernetes-config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Teleport settings

# Deploy Teleport
terraform init  
terraform apply
```

### 4. Test the Workflow

```bash
# Make script executable
chmod +x ./update-teleport.sh

# Check deployment status
./update-teleport.sh status

# Access your demo environment
open https://your-cluster-name.yourdomain.com
```

## 🔧 Configuration

### EKS Infrastructure (`1-eks-cluster/terraform.tfvars`)

```hcl
# Basic Infrastructure
region = "us-east-2"
name   = "presales"              # Used for cluster naming
user   = "your-user@company.com"

# Kubernetes Version
ver_cluster = "1.33"

# Optional: Customize node configuration in main.tf
```

### Teleport Configuration (`2-kubernetes-config/terraform.tfvars`)

```hcl
# Basic Configuration
region       = "us-east-2"
proxy_address = "presales.teleportdemo.com"  # Your Teleport cluster FQDN
user        = "admin@company.com"           # user for ACME certificates

# Teleport Version (update this for monthly releases)
teleport_version = "18.1.6"

# DNS Configuration (optional - leave empty to skip DNS setup)
domain_name = "teleportdemo.com"  # Your Route53 hosted zone

# SAML Configuration
okta_metadata_url = "https://your-okta.okta.com/app/.../metadata"

# Optional: Additional SAML Connector
enable_okta_preview       = true
okta_preview_metadata_url = "https://gravitational-preview.oktapreview.com/app/.../metadata"

# Optional: Access Lists (if supported in your Teleport version)
enable_access_lists = false
```

## ⚡ Fast Update Workflow

The key advantage of this setup is **fast, safe updates**:

### Monthly Teleport Updates (2-3 minutes)

```bash
# Check available versions
./update-teleport.sh versions

# Update to new version (EKS infrastructure stays untouched)
./update-teleport.sh update-teleport 17.5.4

# Verify update
./update-teleport.sh status
```

### Rollback if Needed

```bash
# Rollback to previous version
./update-teleport.sh rollback

# Check status
./update-teleport.sh status
```

### EKS Updates (Rare)

```bash
# Only needed for Kubernetes version updates
cd 1-eks-cluster
# Update ver_cluster in terraform.tfvars
terraform apply

# Teleport automatically adapts via remote state
```

## 📋 Included Resources

### Infrastructure (1-eks-cluster)
- **VPC** with public/private subnets across 3 AZs
- **EKS cluster** with managed node groups (Bottlerocket)
- **Essential addons**: EBS CSI, CoreDNS, VPC-CNI, kube-proxy
- **IRSA roles** for proper permissions
- **Cost optimizations**: SPOT instances, single NAT gateway

### Teleport Configuration (2-kubernetes-config)
- **Teleport cluster** with operator enabled
- **SAML connectors**: Primary and preview Okta integrations
- **Roles**: dev-access, prod-access, reviewer, requester
- **Login rules** for trait mapping
- **Access lists** for support engineers (optional)
- **DNS records** (if domain configured)

### Demo Applications (demo-apps.tf)
- **Namespaces**: dev and prod for testing access
- **Applications**: nginx deployments for demonstrating role-based access

## 🧪 Testing Your Deployment

### 1. Verify Infrastructure

```bash
# Check EKS cluster
kubectl get nodes
kubectl get namespaces

# Check Teleport pods
kubectl get pods -n teleport-cluster
```

### 2. Verify Teleport Resources

```bash
# Check operator resources
kubectl get teleportroles,teleportsamlconnectors,teleportloginrules -n teleport-cluster

# Should show:
# - teleportroles: dev-access, prod-access, reviewer, requester
# - teleportsamlconnectors: okta-dlg, okta-preview (if enabled)
# - teleportloginrules: okta-preferred-login-rule
```

### 3. Test Demo Applications

```bash
# Check demo apps
kubectl get pods -n dev
kubectl get pods -n prod

# Test role-based access via Teleport
```

### 4. Test SAML Authentication

- Access your Teleport cluster URL
- Should see both SAML login options (if preview enabled)
- Test login with different Okta groups to verify role mapping

## 🚨 Troubleshooting

### Common Issues

#### CRD Management Conflicts
```bash
# If you see CRD-related errors, ensure Helm manages CRDs:
# In main.tf, these should be commented out:
# disable_crd_hooks = true
# skip_crds = true
```

#### Namespace Stuck During Destroy
```bash
# Force cleanup stuck resources
kubectl delete teleportroles,teleportsamlconnectors,teleportloginrules --all -n teleport-cluster --timeout=60s

# Remove finalizers if stuck  
kubectl get teleportroles,teleportsamlconnectors,teleportloginrules -n teleport-cluster -o name | \
  xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge

# Delete Helm release
helm uninstall teleport-cluster -n teleport-cluster

# Force delete namespace
kubectl delete namespace teleport-cluster --timeout=60s
```

#### Remote State Access Issues
```bash
# Verify EKS outputs are available
cd 1-eks-cluster
terraform output cluster_name
terraform output cluster_endpoint

# Test remote state access
cd ../2-kubernetes-config
terraform console <<< "data.terraform_remote_state.eks.outputs.cluster_name"
```

#### Role Syntax Errors
```bash
# YAML syntax is sensitive - ensure proper formatting:
# WRONG: duplicate keys
app_labels = { tier = ["dev"], tier = ["prod"] }

# RIGHT: combined arrays  
app_labels = { tier = ["dev", "prod"] }
```

### Recovery Commands

```bash
# Complete cleanup and restart
./update-teleport.sh cleanup

# Validate environment
./update-teleport.sh validate

# Check status
./update-teleport.sh status
```

### Certificate Troubleshooting

If certificates aren't issuing:
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate teleport-tls -n teleport-cluster

# Verify DNS challenge
kubectl describe challenge -n teleport-cluster

# Check IAM role association
kubectl describe sa cert-manager -n cert-manager | grep role-arn
```

## 📈 Performance Comparison

| Task | Old Approach | New Approach | Time Saved |
|------|-------------|--------------|------------|
| Initial Deploy | 15-20 min | 15-20 min | - |
| Teleport Update | 15-20 min | 2-3 min | **85% faster** |
| Rollback | 15-20 min | 2-3 min | **85% faster** |
| Configuration Change | Manual coordination | Automated | **100% automated** |

## 🤝 Best Practices

### For Demo Environments
- **Use meaningful cluster names** that customers can remember
- **Set appropriate session TTLs** (dev: 8h, prod: 2h for demos)
- **Test both SAML connectors** before customer demos
- **Keep license.pem secure** and in the correct location

### For Monthly Updates
1. **Check versions**: `./update-teleport.sh versions`
2. **Test in development** environment first if possible
3. **Update during maintenance windows** for production demos
4. **Verify functionality** after each update
5. **Document any issues** for future reference

### For Troubleshooting
- **Use the status command** first: `./update-teleport.sh status`
- **Check kubectl resources** if issues occur
- **Review Terraform state** for configuration drift
- **Keep backups** of working configurations

## 🚀 Advanced Usage

### Custom Backend Configuration

For team environments, use S3 remote state:

```hcl
# In 2-kubernetes-config/main.tf
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "eks-cluster/terraform.tfstate"
    region = var.region
  }
}
```

### Adding Custom Resources

Add new Teleport resources as `kubectl_manifest` resources:

```hcl
resource "kubectl_manifest" "custom_role" {
  depends_on = [time_sleep.wait_for_operator]
  
  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name      = "custom-role"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      # Role specification
    }
  })
}
```

### Environment-Specific Configurations

```bash
# Use different tfvars for different environments
terraform apply -var-file="production.tfvars"
terraform apply -var-file="staging.tfvars"
```

## 📚 Additional Resources

- [Teleport Helm Chart Reference](https://goteleport.com/docs/reference/helm-reference/teleport-cluster/)
- [Teleport Kubernetes Operator Guide](https://goteleport.com/docs/deploy-a-cluster/helm-deployments/kubernetes-operator/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🚫 Intentionally Omitted (Cost Savings)

- High Availability (`replicaCount: 1`)
- Multi-AZ NAT Gateways
- Production-grade instance types
- Prometheus/Grafana monitoring stack
- Backup automation
- Advanced pod autoscaling

---

## 🎯 Success Metrics

- ✅ **Professional appearance** with valid SSL certificates
- ✅ **Quick setup** - Under 20 minutes from scratch
- ✅ **Fast updates** - 2-3 minute version changes
- ✅ **Cost effective** - Under $200/month
- ✅ **Demo ready** - Includes test apps and multiple auth methods
- ✅ **Reliable** - No ACME failures during customer demos

**Happy Teleporting!** 🚀