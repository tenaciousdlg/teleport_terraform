variable "region" {
  default = "us-east-2" # replace with your preferred aws region
  type    = string
}

# used for tracking resources
variable "user" {
  description = "Name of the user deploying the infrastructure"
  type        = string
  default     = "terraform"
}

# variables related to dns deployment. May be optional depending on your configuration 
variable "domain_name" {
  description = "domain name to query"
  default     = "foo.com"
  type        = string
}

variable "subdomain" {
  description = "subdoman for teleport off domain_name variable"
  default     = "v16"
  type        = string
}
