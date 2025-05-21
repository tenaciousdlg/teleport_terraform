resource "random_string" "uuid" {
  length  = 4
  special = false
}

# TLS keys and certs
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem       = tls_private_key.ca_key.private_key_pem
  subject {
    common_name  = "example"
    organization = "example"
  }
  validity_period_hours = 87600
  is_ca_certificate     = true
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server_csr" {
  private_key_pem = tls_private_key.server_key.private_key_pem
  subject {
    common_name  = var.mysql_hostname
    organization = "example"
  }
  dns_names = [var.mysql_hostname, "localhost", "127.0.0.1"]
}

resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem     = tls_cert_request.server_csr.cert_request_pem
  ca_private_key_pem   = tls_private_key.ca_key.private_key_pem
  ca_cert_pem          = tls_self_signed_cert.ca_cert.cert_pem
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "teleport_provision_token" "db" {
  version = "v2"
  spec = {
    roles = ["Db", "Node"]
    name  = random_string.uuid.result
  }
  metadata = {
    expires = timeadd(timestamp(), "1h")
  }
}

resource "aws_instance" "mysql" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  associate_public_ip_address = true
  subnet_id              = var.subnet_id
  security_groups        = var.security_group_ids

  user_data = templatefile("${path.module}/userdata.tpl", {
    token     = teleport_provision_token.db.metadata.name
    domain    = var.proxy_address
    major     = var.teleport_version
    ca        = tls_self_signed_cert.ca_cert.cert_pem
    cert      = tls_locally_signed_cert.server_cert.cert_pem
    key       = tls_private_key.server_key.private_key_pem
    tele_ca   = var.teleport_db_ca
  })

  tags = {
    Name = "${var.env}-mysql"
  }
}

resource "teleport_database" "mysql" {
  version = "v3"
  metadata = {
    name        = "${var.env}-mysql"
    description = "Teleport-managed MySQL for ${var.env}"
    labels = {
      tier  = var.env
    }
  }

  spec = {
    protocol = "mysql"
    uri      = "localhost:3306"
    ca_cert  = tls_self_signed_cert.ca_cert.cert_pem
  }
}
