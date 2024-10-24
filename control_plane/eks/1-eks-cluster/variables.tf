variable "region" {
  default = "us-east-2" # replace with your preferred aws region
  type    = string
}

# used for tracking resources
variable "name" {
  description = "Name of the EKS  deployment"
  type        = string
  default     = "terraform"
}

# used for tracking resources
variable "user" {
  description = "Name of the user managing the deployment"
  type        = string
  default     = "user@example.com"
}