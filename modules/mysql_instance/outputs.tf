output "subnet_id" {
  description = "ID of the subnet used by the MySQL instance"
  value       = var.create_network ? aws_subnet.main[0].id : var.subnet_id
}

output "security_group_id" {
  description = "ID of the security group used by the MySQL instance"
  value       = var.create_network ? aws_security_group.main[0].id : var.security_group_ids[0]
}

output "ca_cert" {
  description = "The custom CA cert used to sign the DB TLS cert"
  value       = tls_self_signed_cert.ca_cert.cert_pem
}