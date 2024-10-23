variable "proxy_address" {
  type        = string
  description = "Host of the Teleport Proxy Service"
}

variable "okta_sso_app" {
  type        = string
  description = "Value of the Okta SSO URL | ex: dev-4389181381.okta.com/app/e4kj324hj13h4j3k13"
}

variable "identity_path" {
  type        = string
  description = "file path location of identity file for teleport terraform provider"
}