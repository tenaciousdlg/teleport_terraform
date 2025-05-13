# Self Hosted Teleport Cluster running on Amazon Linux 2023 with Proxy-Peering enabled 

The purpose of this example is to show how a basic Proxy Peered Teleport cluster can be configured. 

To complete this workflow several Teleport guides are used:

- [Self-Hosted Demo Cluster](https://goteleport.com/docs/admin-guides/deploy-a-cluster/linux-demo/)

This document shows an example of setting up a Teleport Auth/Proxy/SSH services on a single Linux VM.

- [Proxy Peering: Architecture](https://goteleport.com/docs/reference/architecture/proxy-peering/)

- [Proxy Peering Migration](https://goteleport.com/docs/admin-guides/management/operations/proxy-peering/)

This docuement provides the config changes needed for the primary Auth/Proxy service. 

- [Networking](https://goteleport.com/docs/reference/networking/#public-address)

Covers this important caveat about naming for this type of cluster architecture

> Only a single Proxy Service `public_addr` should be configured. Attempting to have multiple addresses can result in redirects to the first listed address that may not be available to the client.

## Pre-requisites 
- aws-cli
This examples uses AWS and will require AWS CLI access to create resources via Terraform. 
- terraform
This example uses Terraform as the configuration management utility. It has been tested against v1.9*
```bash
❯ terraform version
Terraform v1.9.1
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.97.0
```

## Usage
0. Authenticate to AWS. You should be able to run a command like `aws sts get-caller-identity --query "UserId" --output text`
1. Copy down this Github repository to a local directory.
2. `cd` into the local directory
3. Run `terraform init` to initialize the directory for Terraform
4. Run `terraform plan` and review the output. This will explain the resources (networking, storage, compute, dns) the configuration will create.
5. Run `terraform apply` and approve the changes to create the resources.
OPTIONAL: When done run `terraform destroy` to clean up the resources. 

## Teleport User information
An initial [Teleport Local User](https://goteleport.com/docs/admin-guides/management/admin/users/) is created named `admin`. The login link for this user is stored in the S3 bucket that this configuration creates. To retrieve this run `aws s3 cp s3://your-bucket-name/user.txt -` where `your-bucket-name` is the name of the bucket created by this configuration. 