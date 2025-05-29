output "private_ip" {
  value = aws_instance.windows.private_ip
}

output "private_dns" {
  value = aws_instance.windows.private_dns
}

output "hostname" {
  value = aws_instance.windows.tags["Name"]
}