# Self Hosted Teleport Cluster with Proxy-Peering enabled 

The purpose of this example is to show how a basic Proxy Peered Teleport cluster can be configured. 

To complete this workflow several Teleport guides are used:

- [Self-Hosted Demo Cluster](https://goteleport.com/docs/admin-guides/deploy-a-cluster/linux-demo/)

This document shows an example of setting up a Teleport Auth/Proxy/SSH services on a single Linux VM.

- [Proxy Peering Architecture](https://goteleport.com/docs/reference/architecture/proxy-peering/)

- [Proxy Peering Migration](https://goteleport.com/docs/admin-guides/management/operations/proxy-peering/)

This docuement provides the config changes needed for the primary Auth/Proxy service. 

- [Networking](https://goteleport.com/docs/reference/networking/#public-address)

Covers this important caveat about naming for this type of cluster architecture

> Only a single Proxy Service `public_addr` should be configured. Attempting to have multiple addresses can result in redirects to the first listed address that may not be available to the client.

## Pre-requisites 

- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

This examples uses AWS and will require AWS CLI access to create resources via Terraform. 

- [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

This example uses Terraform as the configuration management utility. It has been tested against `v1.9*`

```bash
❯ terraform version
Terraform v1.9.1
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.97.0
```

This configuration will create a VPC, at least two EC2 instances (running Amazon Linux 2023), IAM policies, and a S3 bucket in AWS. 

## Usage

1. Authenticate to AWS. You should be able to run a command like `aws sts get-caller-identity --query "UserId" --output text`
2. Copy down this Github repository to a local directory.
3. `cd` into the local directory
4. Copy the `terraform.tfvars.example` file to `terraform.tfvars`, or provide input to the variables in another way, and populate the file 
5. Run `terraform init` to initialize the directory for Terraform
6. Run `terraform plan` and review the output. This will explain the resources (networking, storage, compute, dns) the configuration will create.
7. Run `terraform apply` and approve the changes to create the resources.

> OPTIONAL: When done run `terraform destroy` to clean up the resources. 

After a succesful application you will have a Teleport cluster available at `$proxy_address` with 2 proxy services, an auth service, and 2 ssh services. 

## Observations

- A S3 bucket is used to automate the exchange of a join token to the proxy nodes and relaying the initial Teleport user's login information

- The null_resource is used, as this is not an ideal workflow for Terraform, to wait for the config/userdata1 script to run and add the object to the S3 bucket. The obect is the login information. 

### Teleport User information

An initial [Teleport Local User](https://goteleport.com/docs/admin-guides/management/admin/users/) is created named `admin`. 

The login link for this user is stored in the S3 bucket that this configuration creates. 

To retrieve this run `aws s3 cp s3://your-bucket-name/user.txt -` where `your-bucket-name` is the name of the bucket created by this configuration. 

### Example of a populated `terraform.tfvars` file

```bash
parent_domain    = "example.com"
proxy_address    = "dlg.example.com"
teleport_version = "17.4.8"
user             = "dlg@example.com"
```