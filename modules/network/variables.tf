variable "cidr_vpc" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "cidr_subnet" {
  type        = string
  description = "CIDR block for the private subnet"
}

variable "cidr_public_subnet" {
  type        = string
  description = "CIDR block for the public subnet"
}

variable "env" {
  type        = string
  description = "Environment label for tagging"
}