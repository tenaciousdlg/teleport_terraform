# Self Hosted Teleport Cluster with Proxy Peering enabled 

The purpose of this repository is to show how a simple Proxy Peered Teleport cluster can be configured. This requries a baseline knowledge of Teleport and should be viewed as an advanced learning path. 

To complete this workflow several Teleport guides are used:

- [Self-Hosted Demo Cluster](https://goteleport.com/docs/admin-guides/deploy-a-cluster/linux-demo/)

This guide shows an example of setting up Teleport auth, proxy, and ssh services on a single Linux VM.

- [Proxy Peering Architecture](https://goteleport.com/docs/reference/architecture/proxy-peering/)

This document explains the methodology for Proxy Peering. 
>If you're wondering how traffic flows from clients to services with Proxy Peering please read this. 

- [Proxy Peering Migration](https://goteleport.com/docs/admin-guides/management/operations/proxy-peering/)

This document provides the config changes needed on the auth service and proxy service(s). 

- [Networking](https://goteleport.com/docs/reference/networking/#public-address)

This guide covers an important caveat about naming for this type of cluster architecture. This is used in the proxy_service configurations in `/config/userdata1` and `/config/userdata2`

> Only a single Proxy Service `public_addr` should be configured. Attempting to have multiple addresses can result in redirects to the first listed address that may not be available to the client.

## Prerequisites 

- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

This example uses AWS and will require aws CLI access to create resources via Terraform. 

- [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

This example has been tested against Terraform `v1.9*`

```bash
❯ terraform version
Terraform v1.9.1
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.97.0
```

- [Teleport Enterprise](https://goteleport.com/docs/admin-guides/deploy-a-cluster/license/)

The configuration expects the license file to be placed a level up (../license.pem) relative to the directory noted in step 3.

## Usage

1. Authenticate to AWS. You should be able to run a command like `aws sts get-caller-identity --query "UserId" --output text`
2. Copy this Github repository to a local directory on your workstation
3. Navigate or `cd` into the  directory from step 2 
4. Copy the `terraform.tfvars.example` file to `terraform.tfvars`, or provide input to the variables in another way, and populate the file (_a reference is provided below_)
5. Run `terraform init` to initialize (configure) the directory for Terraform usage
6. Run `terraform plan` and review the output. This will explain the AWS resources (networking, storage, compute, dns) the configuration will create
7. Run `terraform apply` and approve the changes to create the resources

> OPTIONAL: When done run `terraform destroy` to clean up the resources. 

After a succesful application you will have a Teleport cluster available at the value of your `$proxy_address` variable. This cluster has 2 (or more) proxy services, an auth service, and 2 (or more) ssh services as part of its inventory. In AWS this configuration will create a VPC, at least two EC2 instances (running Amazon Linux 2023), IAM policies, and a S3 bucket. 

Teleport cluster login information is noted below.  

### Teleport User information

An initial [Teleport Local User](https://goteleport.com/docs/admin-guides/management/admin/users/) is created named `admin`. 

The login link for this user is stored in the S3 bucket that this configuration creates. 

To retrieve this run `aws s3 cp s3://yourbucketname/user -` where `yourbucketname` is the name of the bucket created by this configuration. 

```bash
...
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

teleport_user_login_details = "aws s3 cp s3://dlgproxypeers/user -"
❯ aws s3 cp s3://dlgproxypeers/user -
User "admin" has been created but requires a password. Share this URL with the user to complete user setup, link is valid for 1h:
https://test.example.com:443/web/invite/1..0

NOTE: Make sure test.example.com:443 points at a Teleport proxy which users can access.
```

Then follow the link provided to complete the user sign up. The user has [Access, Auditor, and Editor](https://goteleport.com/docs/admin-guides/access-controls/getting-started/#step-13-add-local-users-with-preset-roles) Teleport Roles assigned. 

#### Observations

- A S3 bucket is used to automate the exchange of a join token to the proxy nodes and relaying the initial Teleport user's login information. This bucket and its information should be considered ephermal 

- This is a demo deployment and is not designed for production usage. 



#### Example of a populated `terraform.tfvars` file

```bash
parent_domain    = "example.com"
proxy_address    = "dlg.example.com"
teleport_version = "17.4.8"
user             = "dlg@example.com"
```

## Ideas, Contributions, Comments?

Pull requests are welcome. I can also be reached at @tenaciousdlg