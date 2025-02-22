1. Prerequisites

Ensure the following tools are installed on your machine:

* Terraform v1.3+

* AWS CLI

* kubectl

* Teleport CLI (tctl & tsh)[https://goteleport.com/download/]

2. Clone the Repository

```
git clone https://github.com/tenaciousdlg/teleport_terraform.git
cd teleport_terraform/control_plane/eks
```

3. Terraform Initialization

Initialize the Terraform working directory:

```
terraform init
```

4. Configure AWS Authentication

Ensure your AWS CLI is configured with appropriate credentials:

```
aws configure
```

5. Create `terraform.tfvars`

Create a `terraform.tfvars` file with the following example values:

```
cluster_name = "teleport-control-plane"
region       = "us-west-2"
node_count   = 3
instance_type = "t3.medium"
```

6. Terraform Plan and Apply

Generate an execution plan:

```
terraform plan
```

Apply the configuration:

```
terraform apply
```

7. Configure Kubectl

Update your kubeconfig to access the cluster:

```
aws eks update-kubeconfig --region us-west-2 --name teleport-control-plane
```

8. Verify EKS Cluster

Check the nodes and pods:

```
kubectl get nodes
kubectl get pods -A
```1. Terraform Authentication Error

Error: `Error: Error creating EKS cluster: AccessDenied`
Solution: Ensure your AWS credentials have the required permissions for EKS:

```
aws sts get-caller-identity
```

2. Kubectl Connection Failure

Error: `Unable to connect to the server: dial tcp: no route to host`
Solution: Ensure your kubeconfig is updated and the cluster is reachable:

```
aws eks update-kubeconfig --region us-west-2 --name teleport-control-plane
```

3. Teleport Pod CrashLoopBackOff

Error: `kubectl get pods -n teleport` shows `CrashLoopBackOff`
Solution: Check the logs of the failing pod:

```
kubectl logs <pod-name> -n teleport
```
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