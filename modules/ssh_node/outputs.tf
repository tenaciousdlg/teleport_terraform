output "provision_token" {
  description = "Provision token for all SSH agents"
  value       = teleport_provision_token.agent.metadata.name
}

output "public_ips" {
  description = "Public IPs of deployed SSH nodes"
  value       = aws_instance.ssh_node[*].public_ip
}
