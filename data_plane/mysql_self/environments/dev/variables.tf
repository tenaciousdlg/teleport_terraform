variable "env" { 
    default = "dev" 
    description = "Environment name (e.g., dev, prod)"
}
variable "user" {
  description = "Username or owner of the environment"
}
variable "proxy_address" {
  description = "Teleport Proxy host address (without https:// prefix)"
}
variable "teleport_version" {
  description = "Teleport version to install on EC2 instance"
}
variable "subnet_id" {
  description = "AWS subnet ID for EC2 instance placement"
}
variable "security_group_id" {
  description = "AWS security group ID for the instance"
}