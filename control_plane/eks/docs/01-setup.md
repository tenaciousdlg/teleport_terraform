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
```