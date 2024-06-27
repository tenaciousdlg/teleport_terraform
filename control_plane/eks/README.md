# Deploying Teleport Cluster on EKS with Terraform

## Overview
This is a Terraform based example of deploying a Teleport Cluster onto EKS. 

This repo requires access to an AWS account to run. It uses the AWS, kubernetes, and helm Terraform providers to deploy a Teleport Cluster on EKS. 

This is done in two `terraform apply` commands in the `1-eks-cluster` and `2-kubernetes-config` directories (example below). The `3-k8s-operator` directory provides example yaml files to be used with the Teleport K8s operator. 

Here is what my directory structure looks like. The `terraform.tfvars` files are used for the input variables in each directory. Environment varibales or alternative means could also be used instead.

```
.
├── 1-eks-cluster
│   ├── main.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── 2-kubernetes-config
│   ├── kubeconfig.tpl
│   ├── main.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── 3-k8s-operator
│   ├── accesslist.yaml
│   ├── login.yaml
│   ├── roles.yaml
│   ├── saml.yaml
│   └── users.yaml
├── README.md
└── license.pem
```

> The enterprise license file is placed above the 3 configuration directories. This is how it is referenced in `2-kubernetes-config/main.tf` within the `kubernetes_secret.license` resource. If you place your `license.pem` file elsewhere you will need to adjust this resource. 

## How to Use

The resources should always be deloyed in the following order.

1. `cd /1-eks-cluster && terraform init && terraform plan && terraform apply`
2. `cd ../2-kubernetes-config && terraform init && terraform plan && terraform apply`
3. `cd ../3-k8s-operator && kubectl apply -n teleport-cluster -f file.yaml` # Applying the yaml files as needed

This means they should be removed in reverse order. Using the above example we'll remove the resources created in `3-k8s-operator` and then the other directories.

1. `kubectl delete -n teleport-cluster -f roles.yaml` # Running this against all created crds
2. `cd ../2-kubernetes-config && terraform refresh && terraform destroy`
3. `cd ../1-eks-cluster && terraform refersh && terraform destroy`

## Configured 

- [Teleport Cluster deployed via Helm](https://goteleport.com/docs/ver/15.x/deploy-a-cluster/helm-deployments/kubernetes-cluster/)
- [Teleport Kubernetes Operator](https://goteleport.com/docs/management/dynamic-resources/teleport-operator/)

## TO DO 
* Slack Plugin
* Role Structures