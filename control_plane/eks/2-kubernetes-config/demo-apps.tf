
# 2-kubernetes-config/demo-apps.tf
#
# Usage notes:
# - All demo namespaces and apps use labels 'tier' and 'team' for Teleport RBAC.
# - Example teams: engineering, support, devops, qa
# - Teleport roles in roles.tf grant access based on these labels.
# - Example: tsh apps ls --labels=tier=dev,team=engineering
#
# To add more teams, duplicate resources with different 'team' values.

# Demo Namespaces

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
    labels = {
      tier = "dev"
      team = "engineering"
    }
  }
  depends_on = [helm_release.teleport_cluster]
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
    labels = {
      tier = "prod"
      team = "engineering"
    }
  }
  depends_on = [helm_release.teleport_cluster]
}

# Demo Applications - Web Apps

resource "kubernetes_deployment" "webapp_dev" {
  metadata {
    name      = "webapp"
    namespace = kubernetes_namespace.dev.metadata[0].name
    labels = {
      tier = "dev"
      team = "engineering"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "nginx-webapp"
        tier = "dev"
        team = "engineering"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-webapp"
          tier = "dev"
          team = "engineering"
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
    labels = {
      tier = "prod"
      team = "engineering"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "nginx-webapp"
        tier = "prod"
        team = "engineering"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-webapp"
          tier = "prod"
          team = "engineering"
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
    labels = {
      tier = "dev"
      team = "engineering"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "nginx-loadbalancer"
        tier = "dev"
        team = "engineering"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-loadbalancer"
          tier = "dev"
          team = "engineering"
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
    labels = {
      tier = "prod"
      team = "engineering"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "nginx-loadbalancer"
        tier = "prod"
        team = "engineering"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-loadbalancer"
          tier = "prod"
          team = "engineering"
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