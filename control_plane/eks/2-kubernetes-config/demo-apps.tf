# 2-kubernetes-config/demo-apps.tf
# OPTIONAL: Add this file to integrate your demo applications from cluster-files/apps.yaml
# This makes them part of the Terraform-managed infrastructure

# Demo Namespaces
resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
    labels = {
      name = "dev"
    }
  }

  depends_on = [helm_release.teleport_cluster]
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
    labels = {
      name = "prod"
    }
  }

  depends_on = [helm_release.teleport_cluster]
}

# Demo Applications - Web Apps
resource "kubernetes_deployment" "webapp_dev" {
  metadata {
    name      = "webapp"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "nginx-webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-webapp"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.23"
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.dev]
}

resource "kubernetes_deployment" "webapp_prod" {
  metadata {
    name      = "webapp"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "nginx-webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-webapp"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.23"
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.prod]
}

# Demo Applications - Load Balancers
resource "kubernetes_deployment" "loadbalancer_dev" {
  metadata {
    name      = "loadbalancer"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "nginx-loadbalancer"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-loadbalancer"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.23"
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.dev]
}

resource "kubernetes_deployment" "loadbalancer_prod" {
  metadata {
    name      = "loadbalancer"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "nginx-loadbalancer"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-loadbalancer"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.23"
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.prod]
}