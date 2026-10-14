variable "name" {
  description = "Name for the fleet. Used for the ALB, target group, launch template and Auto Scaling group."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "alb_subnet_ids" {
  description = "Public subnets for the load balancer, at least two AZs."
  type        = list(string)
}

variable "instance_subnet_ids" {
  description = "Subnets the instances launch in."
  type        = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "instance_security_group_ids" {
  type = list(string)
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 20
}

variable "instance_profile_name" {
  type = string
}

variable "user_data" {
  description = "Plain-text user data. The module base64-encodes it."
  type        = string
  default     = ""
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 6
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "certificate_arn" {
  description = "ACM certificate for HTTPS. Null serves plain HTTP only."
  type        = string
  default     = null
}

variable "health_check_path" {
  type    = string
  default = "/health.php"
}

variable "scale_out_cpu" {
  description = "Average CPU percent that adds an instance."
  type        = number
  default     = 80
}

variable "scale_in_cpu" {
  description = "Average CPU percent that removes an instance."
  type        = number
  default     = 60
}

variable "alarm_actions" {
  description = "SNS topic ARNs for load balancer alarms. Empty skips those alarms."
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
