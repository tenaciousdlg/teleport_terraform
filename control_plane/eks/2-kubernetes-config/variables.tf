variable "cluster_name" {
  type    = string
  default = "test-cluster"
  description = "name of the cluster created in the first step (under the eks-cluster dir)"
}

variable "user" {
  description = "name of the user deploying the infrastructure"
  type        = string
  default     = "terraform"
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