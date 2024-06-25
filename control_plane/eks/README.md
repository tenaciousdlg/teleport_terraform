# Deploying Teleport Cluster on EKS with Terraform

## Configured 

- [Teleport Kubernetes Operator](https://goteleport.com/docs/management/dynamic-resources/teleport-operator/)
- [Teleport Cluster deployed via Helm](https://goteleport.com/docs/ver/15.x/deploy-a-cluster/helm-deployments/kubernetes-cluster/)

## Guide

This repo requires access to an AWS account to run. It uses the AWS, kubernetes, and helm Terraform providers to deploy a Teleport Cluster on EKS. This is done in two `terraform apply` commands in the `1-eks-cluster` and `2-kubernetes-config` directories. The `3-k8s-operator` directory provides example yaml files to be used with the Teleport K8s operator. 

## TO DO 
* Slack Plugin
* Role Structures