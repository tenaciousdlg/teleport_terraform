terraform {
  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 17.0"
    }
  }
}

resource "teleport_database" "mysql" {
  version = "v3"
  metadata = {
    name        = "${var.env}-${var.name}"
    description = "Terraform-managed MySQL for ${var.env}"
    labels = merge(var.labels, {
      "teleport.dev/origin" = "dynamic"
    })
  }
  spec = {
    protocol = "mysql"
    uri      = var.uri
    tls = {
      ca_cert = var.ca_cert
    }
  }
}