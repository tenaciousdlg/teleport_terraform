### Description:
Provisions one or more Linux EC2 instances and joins them to Teleport as SSH nodes using a `teleport.yaml` file configured with dynamic labels and host identity.

### Inputs:
- `env`: Environment label (e.g., `dev`, `prod`)
- `user`: Tagging owner
- `proxy_address`: Teleport Proxy hostname
- `teleport_version`: Teleport version to install
- `agent_count`: Number of SSH nodes to deploy
- `ami_id`: Linux AMI to use
- `instance_type`: EC2 instance type
- `create_network`: Whether to provision VPC, subnet, and security group
- `cidr_vpc`: Optional CIDR block if creating VPC
- `cidr_subnet`: Optional CIDR block if creating subnet

### Outputs:
- EC2 public IPs
- Provision token(s)

### Example Usage:
```hcl
module "ssh_node" {
  source           = "../../modules/ssh_node"
  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version
  agent_count      = 2
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = "t3.micro"
  create_network   = true
}
```

---
Feel free to open a PR or issue to:
- Improve docs
- Suggest new modules
- Add more example use cases