# SSH Getting Started (Teleport)

This example provisions a basic Teleport SSH node demo using the `ssh_node` module. It replicates the [Teleport SSH Getting Started Guide](https://goteleport.com/docs/enroll-resources/server-access/getting-started/) in a reusable format.

---

## What It Deploys

- 3 EC2 instances running Ubuntu 22.04
- Each instance installs Teleport and joins as an SSH node
- All nodes use dynamic labels: `tier = dev`, `os = linux`
- A shared short-lived provision token is used

---

## Usage

1. Log in to your Teleport cluster:

```bash
tsh login --proxy=teleport.example.com --auth=example
eval $(tctl terraform env)
```

2. Customize `terraform.tfvars`:
```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Deploy:
```bash
terraform init
terraform apply
```

4. Validate in Teleport:
```bash
tsh ls --labels=env=dev
```

5. SSH into a node:
```bash
tsh ssh ubuntu@<node-name>
```

6. Tear down:
```bash
terraform destroy
```