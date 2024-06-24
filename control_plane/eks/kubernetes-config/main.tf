# defines aws provider
provider "aws" {
  region = var.region
}

# sources information about an eks cluster based on its name
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# sources auth token for eks cluster
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# local variables
locals {
  tags = {
    ManagedBy = "terraform"
    owner     = var.user
    env       = "dev"
  }
}

# defines k8s provider and auth
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# defines helm provieer and auth 
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# defines config for k8s config file
resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name = var.cluster_name,
    clusterca    = data.aws_eks_cluster.cluster.certificate_authority[0].data,
    endpoint     = data.aws_eks_cluster.cluster.endpoint,
  })
  filename = "./kubeconfig-${var.cluster_name}"
}

# defines helm release for teleport cluster
resource "helm_release" "teleport_cluster" {
  namespace        = "default"
  wait             = true
  timeout          = 300

  name = "teleport-cluster"

  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = var.teleport_ver
  values = [
    <<EOF
clusterName: "${var.domain_name}"
proxyListenerMode: multiplex
acme: true
acmeEmail: "${var.email}"
enterprise: false
EOF
  ]
}
