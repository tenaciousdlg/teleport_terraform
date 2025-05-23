variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "env" {
  description = "Environment label (e.g., dev, prod)"
  type        = string
}

variable "user" {
  description = "Username or identifier for resource tagging"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy address (host only, no https)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install on nodes"
  type        = string
}