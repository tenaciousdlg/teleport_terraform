output "public_ips" {
  value = aws_instance.ssh_node[*].public_ip
}

output "provision_tokens" {
  value = teleport_provision_token.agent[*].spec.name
}