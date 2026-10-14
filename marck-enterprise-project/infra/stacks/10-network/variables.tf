variable "project" {
  type    = string
  default = "marck-enterprise"
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "secondary_region" {
  type    = string
  default = "us-west-2"
}

variable "domain_name" {
  description = "Company domain, for example marckenterprise.com. Route 53 hosts it."
  type        = string
}

variable "create_hosted_zone" {
  description = "True creates the public hosted zone. False looks up an existing zone for domain_name."
  type        = bool
  default     = true
}

variable "admin_cidr" {
  description = "Network allowed to SSH to the web tier, for example your office IP as x.x.x.x/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "nat_mode" {
  description = "single (one NAT gateway per VPC, cheaper) or per_az (survives an AZ outage)."
  type        = string
  default     = "single"
}

variable "enable_ssm_endpoints" {
  description = "Interface endpoints so app2 and db instances, which have no internet route, can use Session Manager. About $45/month."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}
