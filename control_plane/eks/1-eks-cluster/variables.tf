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