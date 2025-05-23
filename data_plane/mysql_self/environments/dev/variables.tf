variable "env" {
  description = "Environment name"
  default     = "dev"
}

variable "region" {
  description = "AWS region to deploy resources"
  default     = "us-east-2"
}

variable "user" {
  description = "Tag to identify the creator"
  type        = string
}

variable "proxy_address" {
  description = "Teleport Proxy address (without protocol)"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to install"
  type        = string
}