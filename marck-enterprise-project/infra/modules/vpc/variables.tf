variable "name" {
  description = "Name of the VPC. Used as the prefix for every resource the module creates."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones, in order. A tier's first CIDR goes in azs[0], the second in azs[1], and so on."
  type        = list(string)
}

variable "tiers" {
  description = <<-EOT
    Subnet tiers keyed by name. type is one of:
      public   - route to the internet gateway
      nat      - outbound internet through a NAT gateway
      isolated - no route outside the VPC
  EOT
  type = map(object({
    cidrs = list(string)
    type  = string
  }))

  validation {
    condition     = alltrue([for t in values(var.tiers) : contains(["public", "nat", "isolated"], t.type)])
    error_message = "Each tier type must be public, nat, or isolated."
  }
}

variable "nat_mode" {
  description = "none, single (one NAT gateway, cheaper), or per_az (one per AZ, survives an AZ outage)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be none, single, or per_az."
  }
}

variable "enable_flow_logs" {
  description = "Send VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Days to keep flow logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
