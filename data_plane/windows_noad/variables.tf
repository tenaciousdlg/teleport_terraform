variable "proxy_service_address" {
  type        = string
  description = "Host and HTTPS port of the Teleport Proxy Service"
}

variable "aws_region" {
  type        = string
  description = "Region in which to deploy AWS resources"
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  default     = "10.1.0.0/20"
}

variable "ssh_key" {
  description = "AWS SSH key for instance"
  default     = ""
}

variable "teleport_version" {
  type        = string
  description = "Version of Teleport to install on each agent"
}

variable "win_user" {
  type        = string
  description = "name of local windows user (e.g. bob)"
}

variable "user" {
  type        = string
  description = "username assgined in description for AWS resources"
}

#test
variable "identity_path" {
  type = string
}