# Self Hosted Teleport Cluster with Proxy Peering enabled 

The purpose of this repository is to show how a simple Proxy Peered Teleport cluster can be configured. This requries a baseline knowledge of Teleport and should be viewed as an advanced learning path. 

To complete this workflow several Teleport guides are used:

- [Self-Hosted Demo Cluster](https://goteleport.com/docs/admin-guides/deploy-a-cluster/linux-demo/)

This guide shows an example of setting up Teleport Auth/Proxy/SSH services on a single Linux VM.

- [Proxy Peering Architecture](https://goteleport.com/docs/reference/architecture/proxy-peering/)

This document explains the methodology for Proxy Peering. If you're wondering how traffic flows from clients to services with Proxy Peering please read this. 

- [Proxy Peering Migration](https://goteleport.com/docs/admin-guides/management/operations/proxy-peering/)

This docuement provides the config changes needed for the primary Auth/Proxy service. 

- [Networking](https://goteleport.com/docs/reference/networking/#public-address)

This guide covers an important caveat about naming for this type of cluster architecture:

> Only a single Proxy Service `public_addr` should be configured. Attempting to have multiple addresses can result in redirects to the first listed address that may not be available to the client.

## Prerequisites 

- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

This example uses AWS and will require aws CLI access to create resources via Terraform. 

This configuration will create a VPC, at least two EC2 instances (running Amazon Linux 2023), IAM policies, and a S3 bucket in AWS. 

- [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

This example uses Terraform as the configuration management utility. It has been tested against `v1.9*`

```bash
❯ terraform version
Terraform v1.9.1
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.97.0
```

## Usage

1. Authenticate to AWS. You should be able to run a command like `aws sts get-caller-identity --query "UserId" --output text`
2. Copy down this Github repository to a local directory
3. Navigate or `cd` into the  directory from step 2
4. Copy the `terraform.tfvars.example` file to `terraform.tfvars`, or provide input to the variables in another way, and populate the file (a reference is provided below)
5. Run `terraform init` to initialize the directory for Terraform 
6. Run `terraform plan` and review the output. This will explain the resources (networking, storage, compute, dns) the configuration will create
7. Run `terraform apply` and approve the changes to create the resources

> OPTIONAL: When done run `terraform destroy` to clean up the resources. 

After a succesful application you will have a Teleport cluster available at `$proxy_address` with 2 proxy services, an auth service, and 2 ssh services as part of its inventory. User login information is noted below.  

## Observations

- A S3 bucket is used to automate the exchange of a join token to the proxy nodes and relaying the initial Teleport user's login information

- The null_resource is used, as this is not an ideal workflow for Terraform, to wait for the config/userdata1 script to run and add the object to the S3 bucket. The obect is the login information. Alternatively this can be gathered using the aws cli. 

### Teleport User information

An initial [Teleport Local User](https://goteleport.com/docs/admin-guides/management/admin/users/) is created named `admin`. 

The login link for this user is stored in the S3 bucket that this configuration creates. 

To retrieve this run `aws s3 cp s3://yourbucketname/user -` where `yourbucketname` is the name of the bucket created by this configuration. 

### Example of a populated `terraform.tfvars` file

```bash
parent_domain    = "example.com"
proxy_address    = "dlg.example.com"
teleport_version = "17.4.8"
user             = "dlg@example.com"
```