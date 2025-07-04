variable "proxy_address" {
  type        = string
  description = "Host of the Teleport Proxy Service"
}

variable "proxy_address_port" {
  type        = string
  description = "HTTPS port of the Teleport Proxy Service"
  default     = "443"
}

variable "aws_region" {
  type        = string
  description = "Region in which to deploy AWS resources"
}

variable "teleport_version" {
  type        = string
  description = "Version of Teleport to install on each agent"
}

variable "user" {
  type        = string
  description = "username assigned in description for AWS resources"
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  default     = "10.1.0.0/20"
}
