output "private_ip" {
  value = aws_instance.windows.private_ip
}

output "private_dns" {
  value = aws_instance.windows.private_dns
}

output "hostname" {
  value = aws_instance.windows.tags["Name"]
}

output "subnet_id" {
  description = "Subnet ID used by the Windows instance"
  value       = var.create_network ? aws_subnet.main[0].id : var.subnet_id
}

output "security_group_id" {
  description = "Security group ID used by the Windows instance"
  value       = var.create_network ? aws_security_group.main[0].id : var.security_group_ids[0]
}
