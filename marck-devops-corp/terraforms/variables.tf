variable "name_prefix" {
  description = "Name used on resources. S3 bucket names must be globally unique, so change this before apply if the default is taken."
  type        = string
  default     = "marck-devops-corp"
}

variable "domain_name" {
  description = "Public DNS name you control. Route 53 records and the certificates use it."
  type        = string
  default     = "marck-devops-corp.example"
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "secondary_region" {
  type    = string
  default = "us-west-2"
}

variable "primary_azs" {
  description = "Two Availability Zones for the Virginia networks."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "secondary_azs" {
  description = "Two Availability Zones for the Oregon network."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "admin_cidr" {
  description = "Network allowed to open SSH to the bastion. Replace the documentation range before apply."
  type        = string
  default     = "203.0.113.0/24"
}

variable "gitlab_url" {
  description = "GitLab instance that assumes the deploy roles."
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_oidc_subjects" {
  description = "GitLab OIDC subject claims allowed to assume the pipeline roles."
  type        = list(string)
  default     = ["project_path:root/marck-devops-corp:ref_type:branch:ref:main"]
}

variable "aurora_engine_version" {
  description = "Aurora MySQL engine version. Adjust to a version offered in both regions."
  type        = string
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "aurora_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "web_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "ami_id" {
  description = "Optional web AMI. Leave empty to use the current Amazon Linux 2023 image."
  type        = string
  default     = ""
}

variable "ami_id_west" {
  description = "Optional Oregon web AMI. Leave empty to use the current Amazon Linux 2023 image in that region."
  type        = string
  default     = ""
}

variable "fsx_storage_capacity" {
  description = "Lustre persistent capacity in GiB. 1200 is the minimum for PERSISTENT_2."
  type        = number
  default     = 1200
}
