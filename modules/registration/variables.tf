variable "resource_type" {
  description = "Teleport resource type: database or app"
  type        = string
  default     = "database"
}

variable "name" {
  description = "Name of the Teleport resource"
  type        = string
}

variable "description" {
  description = "Description for the resource"
  type        = string
  default     = ""
}

variable "protocol" {
  description = "Protocol (for databases only)"
  type        = string
  default     = ""
}

variable "uri" {
  description = "Connection URI (host:port or app URI)"
  type        = string
}

variable "ca_cert_chain" {
  description = "CA certificate chain (PEM)"
  type        = string
  default     = ""
}

variable "public_addr" {
  description = "Public address for apps"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the resource"
  type        = map(string)
}