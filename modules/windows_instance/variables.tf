variable "env" {
  description = "Environment tag (e.g., dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Windows Server"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t3.large)"
  type        = string
  default     = "t3.large"
}

variable "subnet_id" {
  description = "Optional subnet ID if not creating one"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Optional SGs if not creating one"
  type        = list(string)
  default     = null
}

variable "user" {
  description = "User email or name to derive tag"
  type        = string
}

variable "proxy_address" {
  description = "Teleport proxy address (without protocol)"
  type        = string
}

variable "ami_search" {
  description = "AMI name search filter for Windows"
  type        = string
  default     = "Windows_Server-2019-English-Full-Base-*"
}

variable "teleport_version_channel" {
  description = "Teleport upgrade channel (e.g. /v1/webapi/automaticupgrades/channel/default/version)"
  type        = string
  default     = "/v1/webapi/automaticupgrades/channel/default/version"
}

variable "create_network" {
  description = "Whether to create a new VPC, subnet, and SG"
  type        = bool
  default     = true
}

variable "cidr_vpc" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.3.0/24"
}
variable "teleport_version" {
  description = "Teleport version to install (e.g., 17.4.8)"
  type        = string
}