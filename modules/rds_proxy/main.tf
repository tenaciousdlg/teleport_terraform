##################################################################################
# RDS Proxy Module - Reusable across RDS implementations
##################################################################################

# Random password for RDS
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
}

# Local variable to extract username from email
locals {
  user = lower(split("@", var.user)[0])
}

# Secrets Manager for RDS credentials
resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${local.user}-${var.env}-rds-${var.engine}-${random_string.suffix.result}"
  description             = "RDS ${var.engine} credentials for Teleport"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.rds_password.result
  })
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "rds_proxy" {
  name = "${local.user}-${var.env}-rds-proxy-${var.engine}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for RDS Proxy
resource "aws_iam_role_policy" "rds_proxy" {
  name = "${local.user}-${var.env}-rds-proxy-policy-${var.engine}"
  role = aws_iam_role.rds_proxy.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_credentials.arn
      }
    ]
  })
}

# RDS Proxy
resource "aws_db_proxy" "main" {
  name                   = "${local.user}-${var.env}-rds-${var.engine}-proxy"
  engine_family          = var.engine_family
  debug_logging          = false
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn              = aws_iam_role.rds_proxy.arn
  vpc_subnet_ids        = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.rds_credentials.arn
  }
}

# RDS Proxy Target
resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  db_instance_identifier = var.db_instance_identifier
  target_group_name      = "default"
}