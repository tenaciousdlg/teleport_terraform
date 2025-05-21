resource "teleport_database" "mysql" {
  version = "v3"
  metadata = {
    name        = "${var.env}-${var.name}"
    description = "Teleport-managed MySQL for ${var.env}"
    labels = merge(var.labels, {
      "teleport.dev/origin" = "dynamic"
    })
  }
  spec = {
    protocol = "mysql"
    uri      = var.uri
    tls = {
      ca_cert = var.ca_cert_chain
    }
  }
}