variable "env" {
  description = "Environment tag (e.g., dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Windows Server"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t3.large)"
  type        = string
  default     = "t3.large"
}

variable "subnet_id" {
  description = "Optional subnet ID if not creating one"
  type        = string
}

variable "security_group_ids" {
  description = "Optional SGs if not creating one"
  type        = list(string)
}

variable "user" {
  description = "User email or name to derive tag"
  type        = string
}

variable "proxy_address" {
  description = "Teleport proxy address (without protocol)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install (e.g., 17.4.8)"
  type        = string
}