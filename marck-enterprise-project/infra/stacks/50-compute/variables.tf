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

variable "state_bucket" {
  type = string
}

variable "golden_ami_name" {
  description = "Name prefix of the Packer-built web AMI (packer/web-ami.pkr.hcl). Empty uses the latest Amazon Linux 2023 and installs packages at boot."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Web fleet instance type."
  type        = string
  default     = "t3.micro"
}

variable "tier_instance_type" {
  description = "Instance type for the one-per-subnet case study instances."
  type        = string
  default     = "t3.micro"
}

variable "fleet_min" {
  type    = number
  default = 2
}

variable "fleet_max" {
  type    = number
  default = 6
}

variable "west_fleet_min" {
  description = "Warm standby size in Oregon."
  type        = number
  default     = 2
}

variable "enable_https" {
  description = "Issue ACM certificates for app.<domain>. Needs the hosted zone to be delegated at the registrar."
  type        = bool
  default     = true
}

variable "enable_fsx" {
  description = "FSx for OpenZFS shared file system mounted by the production fleet."
  type        = bool
  default     = true
}

variable "fsx_storage_gib" {
  type    = number
  default = 64
}

variable "enable_tier_instances" {
  description = "Launch one instance in every subnet, named after the subnet (VPC case study)."
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Optional OpenSSH public key for the web tier and QA instances. Session Manager works without it."
  type        = string
  default     = ""
}

variable "ebs_volumes" {
  description = <<-EOT
    Extra EBS volumes on the production web tier instance (EC2/EBS case study).
    Remove an entry to detach and delete that volume. Raise size to extend it.
  EOT
  type = map(object({
    size   = number
    device = string
  }))
  default = {
    data1 = { size = 10, device = "/dev/sdf" }
    data2 = { size = 10, device = "/dev/sdg" }
  }
}
