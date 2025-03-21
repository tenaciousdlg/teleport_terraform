# Machine ID Terraform Example

This repo is largely based on the Teleport Ansible [guide](https://goteleport.com/docs/enroll-resources/server-access/guides/ansible/) and attempts to show a IaaC example of that flow. 

## Prereqs

- AWS cli access to create EC2 instance plus a VPC and its components. You should be able to run the following:

```sh
aws sts get-caller-identity --query "UserId" --output text
```

- Teleport Terraform provider access. Easiest way to do this is the following:

```sh
tsh login --proxy=clustername.com:443 clustername.com:443
eval $(tctl terraform env)
```

- Create a `terraform.tfvars` file or provide these variables.

```sh
proxy_service_address = "clustername.com"
teleport_version      = "17.3.3"
aws_region            = "us-east-2"
user                  = "user@example.com"
```

## What does this do?

Review `main.tf` and `config/userdata` as they control what is being created. 

In `main.tf` an EC2 instance is create with affilaited networking (VPC). Additionally a Teleport provision token is created to join the Teleport Machine ID process (aka tbot) to the Teleport cluster. It then creates a Teleport Bot called `ansible`, a Teleport role for the bot and local user to tie these together. 

In `config/userdata` a bash script is used to configure the EC2 instance. The provision token is injected into the EC2 instance along with creating the tbot process as a systemd service. It pushes it output to `/opt/machine-id` and its config file at `/etc/tbot.yaml`

## How to run

Once the instance spins up and registers itself to the Teleport cluster login as the `ubuntu` user and `cd` to the `ubuntu` directory present in the `ubuntu` user's home directory. There will be an `ansible.cfg` and `playbook.yaml` file. You will need to create a `hosts` file adjacent to the other two files. The easiest way to do this is from the terminal that you logged into Teleport with run the following:

```sh
tsh ls --format=json | jq -r '.[].spec.hostname'
```

This Ansible bot is able to run against SSH nodes as `ubuntu` or `ec2-user`. If you need additional users modify the `teleport_role.ansible` resource in `main.tf` as appropirate. 

The included playbook leverages a [static host inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_dynamic_inventory.html#static-groups-of-dynamic-groups). Here is an example of how a `hosts` file could look:

```sh
[amazon_linux_hosts]
ssh-0
ssh-1
ssh-2
windows-jump

[ubuntu_hosts]
ansible
multi-node
```

The names of these nodes were derived from the `tsh ls` command. 

With the `hosts` file created you can then run the playbook.

```sh
ansible-playbook -i hosts playbook.yaml 
```

## Ideas, Comments, Questions?

Please feel free to reach out or create Pull Requests with any ideas on how to improve the project. 