##################################################################################
# VARIABLES
##################################################################################
variable "proxy_service_address" {
  type        = string
  description = "hostname of the teleport environment"
}

variable "aws_region" {
  type        = string
  description = "region to deploy AWS resources"
}

variable "teleport_version" {
  type        = string
  description = "Version of Teleport to install on each agent"
}

variable "user" {
  type        = string
  description = "username assgined in description for AWS resources"
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  default     = "10.1.0.0/20"
}
##################################################################################