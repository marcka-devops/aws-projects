variable "project" {
  type    = string
  default = "marck-enterprise"
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  type = string
}

variable "asset_expiration_days" {
  description = "Objects in the assets bucket are deleted after this many days (S3 case study: 75)."
  type        = number
  default     = 75
}
