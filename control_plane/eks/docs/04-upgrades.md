1. Upgrade Terraform Provider Versions

Update the `provider` block in `versions.tf` to the desired version.
Example:

```
terraform {
  required_providers {
    aws = "~> 5.0"
    kubernetes = "~> 2.0"
  }
}
```

2. Upgrade EKS Cluster

Update the EKS version in `main.tf`:

```
resource "aws_eks_cluster" "teleport" {
  version = "1.29"
}
```

Apply the changes:

```
terraform plan
terraform apply
```

3. Upgrade Teleport Version

Update the Teleport Helm chart version in the `helm_release` resource:

```
resource "helm_release" "teleport" {
  chart     = "teleport"
  version   = "13.3.1"
}
```

Apply the update:

```
terraform apply
```

4. Post-Upgrade Validation

* Verify EKS node status:

```
kubectl get nodes
```

* Confirm Teleport pods are running:

```
kubectl get pods -n teleport
```