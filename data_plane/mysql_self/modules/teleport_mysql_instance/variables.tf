variable "env" {}
variable "user" {}
variable "proxy_address" {}
variable "teleport_version" {}
variable "teleport_db_ca" {}
variable "mysql_hostname" { default = "mysql.example.internal" }
variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" { type = list(string) }