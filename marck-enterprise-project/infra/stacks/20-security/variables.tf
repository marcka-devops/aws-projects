variable "project" {
  type    = string
  default = "marck-enterprise"
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_regions" {
  description = "Regions the operator account may act in."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "ops_user_name" {
  description = "Console user from the IAM case study."
  type        = string
  default     = "marck-ops"
}

variable "create_console_login" {
  description = "Create a console password for the ops user. It must be changed at first sign-in."
  type        = bool
  default     = true
}

variable "console_password_pgp_key" {
  description = "Optional base64 PGP public key or keybase:username. When set, the initial password is encrypted and is not stored in plain text in state."
  type        = string
  default     = null
}

variable "alert_email" {
  description = "Email that receives operational alarms and budget alerts. Empty skips the subscription."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget. Alerts at 80% forecast and 100% actual."
  type        = number
  default     = 300
}

variable "enable_guardduty" {
  type    = bool
  default = true
}

variable "cloudtrail_retention_days" {
  type    = number
  default = 365
}
