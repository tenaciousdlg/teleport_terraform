##################################################################################
# OUTPUTS
##################################################################################
output "db_password" {
  value     = random_password.rds_password.result
  sensitive = true
}

output "proxy_endpoint" {
  value = aws_db_proxy.main.endpoint
}

output "secret_arn" {
  value = aws_secretsmanager_secret.rds_credentials.arn
}