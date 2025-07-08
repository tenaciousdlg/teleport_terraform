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

# New variables for RDS support
variable "create_secondary_subnet" {
  type        = bool
  description = "Create a secondary private subnet (required for RDS)"
  default     = false
}

variable "cidr_secondary_subnet" {
  type        = string
  description = "CIDR block for the secondary private subnet"
  default     = ""
}

variable "create_db_subnet_group" {
  type        = bool
  description = "Create a DB subnet group for RDS"
  default     = false
}