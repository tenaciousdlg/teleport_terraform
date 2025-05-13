variable "cidr_block" {
  type = string
  default = "10.0.0.0/16"
  description = "cidr block for cluster"
}
variable "ec2main_size" {
  type = string
  default = "t3.small"
  description = "size of ec2 instance for auth/proxy"
}
variable "ec2proxy_size" {
  type = string
  default = "t3.micro"
  description = "size of ec2 instance for proxy peer"
}
variable "parent_domain" {
  type = string
  description = "domain to create teleport cluster off of (e.g. example.com)"
}
variable "proxy_address" {
  type = string
  description = "fully qualified domain name of teleport cluster (e.g. teleport.example.com)"
}
variable "proxy_count" {
  type = string
  default = "4"
  description = "number of ec2s to create as proxies"
}
variable "region" {
  type = string
  default = "us-east-2"
  description = "aws region to deploy cluster into"
}
variable "subnet" {
  type = string
  default = "10.0.0.0/24"
  description = "subnet for cluster out of cidr block"
}
variable "teleport_version" {
  type = string
  description = "full version of teleport to use (e.g. 17.4.8)"
}
variable "user" {
  type = string
  description = "SSO username; used for Teleport purposes (e.g. jsmith@example.com)"
}