variable "proxy_service_address" {
  type        = string
  description = "Host and HTTPS port of the Teleport Proxy Service"
}

variable "teleport_join_method" {
  type    = string
  default = "token"
}

variable "teleport_token_name" {
  type    = string
  default = "/var/lib/teleport/token"
}

variable "ssh_key" {
  description = "AWS SSH key for instance"
  default     = "dlg-aws"
}

variable "teleport_install_type" {
  type    = string
  default = "cloud"
}

variable "teleport_install_upgrader" {
  type    = string
  default = "true"
}


variable "windows_machine_size" {
  type    = string
  default = "t2.medium"
}

variable "teleport_windows_label" {
  type    = string
  default = "tier: prod"
}

variable "teleport_ssh_label" {
  type    = string
  default = "tier: prod"
}

variable "agent_machine_name" {
  type    = string
  default = "windows-jump"
}

variable "ssh_enhanced_recording_bool" {
  type    = string
  default = "false"
}

variable "ami_windows_search" {
  type    = string
  default = "Windows_Server-2019-English-Full-Base-*"
}

variable "teleport_version_channel" {
  type    = string
  default = "/v1/webapi/automaticupgrades/channel/default/version"
}

variable "ami_amazonlinx_search" {
  type    = string
  default = "al2023-ami-*-x86_64"
}

variable "aws_key_label" {
  type    = string
  default = "tier"
}

variable "aws_value_label" {
  type    = string
  default = "dev"
}


variable "agent_machine_size" {
  type    = string
  default = "t2.small"
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
  default     = "10.1.0.0/24"
}

variable "cidr_subnet2" {
  description = "CIDR block for subnet 2"
  default     = "10.1.1.0/24"
}


variable "win_user" {
  type        = string
  description = "name of local windows user (e.g. bob)"
}

variable "user" {
  type        = string
  description = "username assgined in description for AWS resources"
}

