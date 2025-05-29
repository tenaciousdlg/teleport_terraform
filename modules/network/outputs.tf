output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "subnet_id" {
  value       = aws_subnet.private.id
  description = "ID of the private subnet"
}

output "security_group_id" {
  value       = aws_security_group.default.id
  description = "ID of the default security group"
}