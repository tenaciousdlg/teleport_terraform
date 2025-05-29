terraform {
  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
    }
  }
}

resource "teleport_database" "this" {
  count = var.resource_type == "database" ? 1 : 0

  version = "v3"
  metadata = {
    name        = var.name
    description = var.description
    labels = merge(var.labels, {
      "teleport.dev/origin" = "dynamic"
    })
  }
  spec = {
    protocol = var.protocol
    uri      = var.uri
    tls = {
      ca_cert = var.ca_cert_chain
    }
  }
}

resource "teleport_app" "this" {
  count = var.resource_type == "app" ? 1 : 0

  version = "v3"
  metadata = {
    name        = var.name
    description = var.description
    labels = merge(var.labels, {
      "teleport.dev/origin" = "dynamic"
    })
  }
  spec = {
    uri      = var.uri
    public_addr = var.public_addr != null ? var.public_addr : var.uri
  }
}