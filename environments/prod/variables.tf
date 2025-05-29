variable "env" {
  description = "Environment (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "user" {
  description = "Creator tag"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy address (no https://)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}