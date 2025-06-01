variable "env" {
  description = "Environment label"
  type        = string
}

variable "user" {
  description = "User tag for EC2"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy hostname (without https)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install (e.g., 16.0.0)"
  type        = string
}
