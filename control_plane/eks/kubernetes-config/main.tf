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

resource "kubernetes_secret" "license" {
  metadata {
    name      = "license"
    namespace = "default"
  }

  data = {
    "license.pem" = file("${path.module}./license.pem")
  }

  type = "Opaque"
}

# defines helm release for teleport cluster
resource "helm_release" "teleport_cluster" {
  namespace = "default"
  wait      = true
  timeout   = 300

  name = "teleport-cluster"

  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = var.teleport_ver
  values = [
    <<EOF
clusterName: "dlgtest.${var.domain_name}"
proxyListenerMode: multiplex
acme: true
acmeEmail: "${var.email}"
enterprise: true
EOF
  ]
}

data "kubernetes_service" "teleport_cluster" {
  metadata {
    name      = helm_release.teleport_cluster.name
    namespace = helm_release.teleport_cluster.namespace
  }
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

# Create DNS records for EKS cluster (based on previously queried Zone)
resource "aws_route53_record" "cluster_endpoint" {
  zone_id    = data.aws_route53_zone.main.zone_id
  name       = "dlgtest.${var.domain_name}"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

resource "aws_route53_record" "wild_cluster_endpoint" {
  zone_id    = data.aws_route53_zone.main.zone_id
  name       = "*.dlgtest.${var.domain_name}"
  type       = "CNAME"
  ttl        = "300"
  records    = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}