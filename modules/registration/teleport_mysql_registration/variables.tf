variable "env" {
  description = "Environment name (e.g., dev, prod)"
}
variable "name" {
  description = "Logical name of the database for resource naming"
  default     = "mysql"
}
variable "uri" {
  description = "Database connection URI (e.g., localhost:3306)"
}
variable "ca_cert" {
  description = "Terraform managed Self Signed PEM-formatted CA certs for the database"
}
variable "labels" {
  description = "Map of labels to apply to the Teleport database resource"
  type        = map(string)
}