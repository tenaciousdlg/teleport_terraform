##################################################################################
# VARIABLES
##################################################################################
variable "proxy_service_address" {
  type        = string
  description = "hostname of the teleport environment"
}

variable "aws_region" {
  type        = string
  description = "region to deploy AWS resources"
}

variable "identity_path" {
  type        = string
  description = "file path location of identity file for teleport terraform provider"
}

variable "ec2_name" {
  type        = string
  description = "name of ec2 instance"
}

variable "teleport_major_version" {
  type = string
  description = "major version of teleport to use in userdata script"
}
##################################################################################