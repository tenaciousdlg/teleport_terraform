variable "cluster_name" {
  description = "name of your teleport cluster (e.g. teleport.example.com)"
  type        = string
}

variable "domain_name" {
  description = "domain name to query for DNS"
  default     = "foo.com"
  type        = string
}

variable "eks_cluster" {
  description = "name of the eks cluster created in the first step"
  default     = "test-cluster"
  type        = string
}

variable "email" {
  description = "email for teleport admin. used with ACME cert"
  type        = string
}

variable "region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}

variable "teleport_ver" {
  description = "full version of teleport (e.g. 17.0.0)"
  type        = string
}