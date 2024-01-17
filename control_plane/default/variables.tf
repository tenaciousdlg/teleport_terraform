variable "proxy_service_address" {
  type        = string
  description = "Host and HTTPS port of the Teleport Proxy Service"
}

variable "aws_region" {
  type        = string
  description = "Region in which to deploy AWS resources"
}

variable "aws_sg" {
  type        = string
  description = "Name for security group"
}

variable "teleport_version" {
  type        = string
  description = "Version of Teleport to install on each agent"
}

variable "instance_hostname" {
  type        = string
  description = "Hostname of instance and how it is identified in AWS"
}

variable "ssh_key_name" {
  type        = string
  description = "Name of key used with AWS"
}

variable "ssh_pub" {
  type        = string
  description = "Public key value of AWS SSH key pair"
}
variable "proxy_service_address" {
  type        = string
  description = "Host and HTTPS port of the Teleport Proxy Service"
}

variable "aws_region" {
  type        = string
  description = "Region in which to deploy AWS resources"
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  default     = "10.1.0.0/20"
}

variable "teleport_version" {
  type        = string
  description = "Version of Teleport to install on each agent"
}

variable "cloudflare_key" {
  type        = string
  description = "API key for Cloudflare user"
}

variable "cloudflare_email" {
  type        = string
  description = "Email for Cloudflare user"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "UUID of Cloudflare Zone for DNS record(s)"
}