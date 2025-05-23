output "ca_cert" {
  value = tls_self_signed_cert.ca_cert.cert_pem
}

output "instance_ip" {
  value = aws_instance.mysql.public_ip
}
