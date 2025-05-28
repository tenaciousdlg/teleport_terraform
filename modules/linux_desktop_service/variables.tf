variable "env" {
  description = "Environment tag (e.g., dev, prod)"
  type        = string
}

variable "user" {
  description = "Tag value for resource creator"
}


variable "proxy_address" {
  description = "Teleport proxy address (host:port)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install (e.g., 17.4.8)"
  type        = string
}

variable "windows_hosts" {
  description = "List of Windows desktops to register with"
  type = list(object({
    name    = string
    address = string
  }))
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2023"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "windows_internal_dns" {
  description = "private dns of windows host"
  type        = string
}

variable "create_network" {
  description = "Whether to create internal VPC, subnet, and security group"
  type        = bool
  default     = true
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}
