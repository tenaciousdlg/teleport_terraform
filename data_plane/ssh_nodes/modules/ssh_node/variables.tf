variable "env" {
  description = "Environment label"
  type        = string
}

variable "user" {
  description = "Creator tag"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy address"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install"
  type        = string
}

variable "agent_count" {
  description = "Number of SSH nodes to deploy"
  type        = number
}

variable "ami_id" {
  description = "AMI to use for SSH nodes"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
}

variable "create_network" {
  description = "Whether to provision networking"
  type        = bool
  default     = true
}

variable "cidr_vpc" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_id" {
  description = "Optional subnet ID if not creating one"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Optional SGs if not creating one"
  type        = list(string)
  default     = null
}