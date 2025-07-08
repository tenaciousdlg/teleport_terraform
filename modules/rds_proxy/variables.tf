variable "user" {
  type        = string
  description = "Username for resource naming"
}

variable "env" {
  type        = string
  description = "Environment name (e.g., dev, prod)"
}

variable "engine" {
  type        = string
  description = "Database engine (mysql, postgres, sqlserver)"
}

variable "engine_family" {
  type        = string
  description = "Database engine family for proxy (MYSQL, POSTGRESQL, SQLSERVER)"
}

variable "db_username" {
  type        = string
  description = "Database admin username"
}

variable "db_instance_identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for RDS proxy"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for RDS proxy"
}