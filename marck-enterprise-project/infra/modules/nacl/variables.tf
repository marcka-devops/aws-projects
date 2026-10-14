variable "name" {
  description = "Name tag for the network ACL."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets that use this ACL."
  type        = list(string)
}

variable "ingress" {
  description = "Inbound rules. protocol is tcp, udp, icmp, or -1 for all traffic."
  type = list(object({
    rule_no   = number
    protocol  = string
    from_port = optional(number, 0)
    to_port   = optional(number, 0)
    cidr      = string
    action    = optional(string, "allow")
  }))
}

variable "egress" {
  description = "Outbound rules, same shape as ingress."
  type = list(object({
    rule_no   = number
    protocol  = string
    from_port = optional(number, 0)
    to_port   = optional(number, 0)
    cidr      = string
    action    = optional(string, "allow")
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
