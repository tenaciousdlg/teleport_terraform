variable "env" {}
variable "name" { default = "mysql" }
variable "uri" {}
variable "ca_cert_chain" {}
variable "labels" { type = map(string) }
