provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "teleport.dev/creator" = "dlg@goteleport.com"
      "Purpose"              = "teleport eks demo access graph add on"
      "Env"                  = "dev"
      ManagedBy              = "terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name = var.cluster_name,
    clusterca    = data.aws_eks_cluster.cluster.certificate_authority[0].data,
    endpoint     = data.aws_eks_cluster.cluster.endpoint,
  })
  filename = "./kubeconfig-${var.cluster_name}"
}

# creates namespace for access graph and its dependencies 
resource "kubernetes_namespace" "access_graph" {
  metadata {
    name = "teleport-access-graph"
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
}

# creates postgres backend for access graph
resource "helm_release" "postgres" {
  namespace = kubernetes_namespace.access_graph.metadata[0].name
  wait      = true
  timeout   = 300

  name = "postgres"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"

  set {
    name  = "auth.username"
    value = "teleport"
  }

  set {
    name  = "auth.password"
    value = "securepassword"
  }

  set {
    name  = "auth.database"
    value = "access_graph"
  }

  depends_on = [
    kubernetes_namespace.access_graph
  ]
}

data "kubernetes_service" "postgres" {
  metadata {
    name      = helm_release.postgres.name
    namespace = helm_release.postgres.namespace
  }
}

resource "kubernetes_secret" "postgres" {
  depends_on = [
    helm_release.postgres
  ]
  metadata {
    name      = "teleport-access-graph-postgres"
    namespace = kubernetes_namespace.access_graph.metadata[0].name
  }

  data = {
    # PostgreSQL URI using the service's internal DNS and helm_release outputs
    uri = "postgres://teleport:securepassword@${data.kubernetes_service.postgres.metadata[0].name}-postgresql.${data.kubernetes_service.postgres.metadata[0].namespace}.svc.cluster.local:5432/access_graph?sslmode=require"
  }
  type = "Opaque"
}

output "posturi" {
  value = "postgres://teleport:securepassword@${data.kubernetes_service.postgres.metadata[0].name}-postgresql.${data.kubernetes_service.postgres.metadata[0].namespace}.svc.cluster.local:5432/access_graph?sslmode=require"
}

# pulls CA from teleport cluster
resource "null_resource" "ca_cert" {
  provisioner "local-exec" {
    command = "curl -s 'https://${var.tele_name}/webapi/auth/export?type=tls-host' -o /tmp/teleport_host_ca.pem"
  }
  triggers = {
    always_run = timestamp()
  }
}

data "local_file" "teleport_ca" {
  depends_on = [null_resource.ca_cert]
  filename   = "/tmp/teleport_host_ca.pem"
}

# cert manager config for access graph
#resource "kubernetes_manifest" "teleport_tls_certificate" {
#  manifest = {
#    apiVersion = "cert-manager.io/v1"
#    kind       = "Certificate"
#    metadata = {
#      name      = "teleport-access-graph-tls"
#      namespace = kubernetes_namespace.access_graph.metadata[0].name
#    }
#    spec = {
#      secretName  = "teleport-access-graph-tls"
#      duration    = "2160h0m0s" # 90 days
#      renewBefore = "720h0m0s"  # 30 days
#      subject = {
#        organizations = ["Teleport Access"]
#      }
#      commonName = "Access Graph"
#      dnsNames = [
#        #"teleport-access-graph.teleport-access-graph.svc.cluster.local"
#        "postgres-postgresql.teleport-access-graph.svc.cluster.local"
#      ]
#      issuerRef = {
#        name = "letsencrypt-staging"
#        kind = "ClusterIssuer"
#      }
#    }
#  }
#}

#data "kubernetes_secret" "teleport_tls_certificate" {
#  metadata {
#    name      = "teleport-access-graph-tls"
#    namespace = kubernetes_namespace.access_graph.metadata[0].name
#  }
#}


# creates access graph 
resource "helm_release" "access_graph" {
  namespace = kubernetes_namespace.access_graph.metadata[0].name
  #wait      = true
  #timeout   = 300

  name       = "teleport-access-graph"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-access-graph"
  #version    = var.teleport_graph_ver

  values = [
    <<EOF
postgres:
  secretName: "${kubernetes_secret.postgres.metadata[0].name}"
tls:
  existingSecretName: "${data.kubernetes_secret.teleport_tls_certificate.metadata[0].name}"
clusterHostCAs:
  - |
    ${indent(4, data.local_file.teleport_ca.content)}
EOF
  ]
}

output "test" {
  value = "${kubernetes_secret.postgres.metadata[0].name}"
}

output "test2" {
  value = "${data.kubernetes_secret.teleport_tls_certificate.metadata[0].name}"
}