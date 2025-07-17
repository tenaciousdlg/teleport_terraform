variable "env" {
  description = "Environment (e.g. dev, prod)"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy address (no https://)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "team" {
  description = "Team label for desktop service"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install"
  type        = string
}

variable "user" {
  description = "Creator tag"
  type        = string
}