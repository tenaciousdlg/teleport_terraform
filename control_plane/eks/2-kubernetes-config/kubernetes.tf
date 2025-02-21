provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "teleport.dev/creator" = var.email
      "tier"                 = "dev"
      "ManagedBy"            = "terraform"
    }
  }
}

# Retrieve EKS cluster configuration
data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
    command     = "aws"
  }
}

# creates ent license as k8s secret
resource "kubernetes_secret" "license" {
  metadata {
    name      = "license"
    namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
  }

  data = {
    # the path module creates a . so only one . is appended to it which inferes .. (the dir above)
    "license.pem" = file("${path.module}./license.pem")
  }

  type = "Opaque"
}

# creates namespace for teleport cluster per https://goteleport.com/docs/ver/15.x/deploy-a-cluster/helm-deployments/kubernetes-cluster/#install-the-teleport-cluster-helm-chart
resource "kubernetes_namespace" "teleport_cluster" {
  metadata {
    name = "teleport-cluster"
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
}

# sources the k8s service (running on an ELB) for the value of the DNS records below
data "kubernetes_service" "teleport_cluster" {
  depends_on = [helm_release.teleport_cluster]
  metadata {
    name      = helm_release.teleport_cluster.name
    namespace = helm_release.teleport_cluster.namespace
  }
}

# used with pvc for persistence with k8s teleport backend
# if postgres or alternative is used this can be removed
resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind = "StorageClass"
  force = true

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
}