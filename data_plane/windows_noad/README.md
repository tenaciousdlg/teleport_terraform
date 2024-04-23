# Windows Non-AD Terraform Example
This repo is based on the [local Windows user](https://goteleport.com/docs/desktop-access/getting-started/) guide from Teleport. 

## Prereqs
* An identity to authenticate against your Teleport cluster (e.g. Identity File supplied by a [Machine ID](https://goteleport.com/docs/machine-id/access-guides/terraform/) process). 

* A Teleport Role allowing access for the value of `win_user` for your Teleport user. The referneced guide provides an example. The following labels are added to both instances for reference in a Role. 

```
env: dev
cloud: aws
```

* AWS credentials. This example will create 2 EC2 instances (Windows is t3.medium and Linux is t3.micro) and their accompanying networking (local RFC1918 ingress and internet egress)


## Usage
1. Copy this repo and add a `terraform.tfvars` file or pass the following variables to Terraform 

```
teleport_version      = "15.2.0"
proxy_service_address = "teleport.example.com"
identity_path         = "/path/to/identity/file"
aws_region            = "us-east-1"
ssh_key               = "key-1"
win_user              = "bob"
user                  = "alice"
```

> Descriptions of each variable can be found in the `variables.tf` file

> Run `terraform init` if this is your first time using the repo

2. Run `terraform plan` and review the output

3. Run `terraform apply` 

4. Login to your Teleport Cluster via the GUI to access the Windows Desktop

## Reference

* Teleport Role allowing access for Bob written in Terraform

```
resource "teleport_role" "windows_bob" {
  version = "v6"
  metadata = {
    name        = "windows_bob"
    description = "Example role for Windows login for user Bob"
  }
  spec = {
    options = {
      record_session = {
        desktop = true
      }
      desktop_clipboard   = false
      create_desktop_user = true
    }
    allow = {
      windows_desktop_labels = {
        "environment" = ["dev", "stage"],
        "cloud"       = ["aws"]
      }
      windows_desktop_logins = ["bob"]
    }
  }
}
```