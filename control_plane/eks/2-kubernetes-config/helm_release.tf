provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
      command     = "aws"
    }
  }
}

# defines helm release for teleport cluster
# teleport k8s operator is added via the operator.enabled arugmenet in the values section below
resource "helm_release" "teleport_cluster" {
  name       = "teleport-cluster"
  namespace  = kubernetes_namespace.teleport_cluster.metadata[0].name
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = var.teleport_ver
  wait       = true
  timeout    = 300

  values = [
    jsonencode({
      clusterName        = var.cluster_name
      proxyListenerMode  = "multiplex"
      acme               = true
      acmeEmail          = var.email
      enterprise         = true
      labels = {
        tier = "dev"
      }
      operator = {
        enabled = true
      }
      persistence = {
        enabled         = false
      }
#      storage = {
#        type = "postgres"
#        postgres = {
#          connection_string = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:5432/teleport_backend?sslmode=disable"
#          audit_events_uri = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:5432/teleport_audit?sslmode=disable#disable_cleanup=false&retention_period=2160h"
#        }
#      }
    })
  ]
}

output "teleport_status" {
  value = helm_release.teleport_cluster.status
}
