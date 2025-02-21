variable "eks_cluster" {
  type        = string
  default     = "test-cluster"
  description = "name of the eks cluster created in the first step"
}

variable "region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}

variable "domain_name" {
  description = "domain name to query for DNS"
  default     = "foo.com"
  type        = string
}

variable "email" {
  description = "email for teleport admin. used with ACME cert"
  type        = string
}

variable "teleport_ver" {
  description = "full version of teleport (e.g. 15.1.0)"
  type        = string
}

variable "cluster_name" {
  description = "name of your teleport cluster (e.g. teleport.example.com)"
  type        = string
}

variable "db_name" {
  description = "postgresdb name to use with teleport"
  type = string
  default = "teleport"
}

variable "db_username" {
  description = "db user for use with teleport"
  type = string
  default = "teleport_db"
}

variable "db_password" {
  description = "db password used for example purposes only"
  type = string
  default = "ChooSeABett3rAU1hMeth0D"
}
