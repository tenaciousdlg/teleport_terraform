# 2-kubernetes-config/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "proxy_address" {
  description = "Name of your Teleport cluster (e.g. teleport.example.com)"
  type        = string
}

variable "domain_name" {
  description = "Parent domain name for DNS records (e.g. demo.com)."
  type        = string
  default     = ""
}

variable "user" {
  description = "Email for Teleport admin and ACME certificate"
  type        = string
}

variable "teleport_version" {
  description = "Teleport version to deploy (e.g. 18.0.0)"
  type        = string
}

variable "okta_metadata_url" {
  description = "Okta SAML metadata URL"
  type        = string
}

variable "okta_preview_metadata_url" {
  description = "Okta preview SAML metadata URL (optional)"
  type        = string
  default     = ""
}

variable "enable_okta_preview" {
  description = "Whether to enable the Okta preview SAML connector"
  type        = bool
  default     = false
}

variable "enable_access_lists" {
  description = "Whether to enable access lists (may not be available in all Teleport versions)"
  type        = bool
  default     = false
}