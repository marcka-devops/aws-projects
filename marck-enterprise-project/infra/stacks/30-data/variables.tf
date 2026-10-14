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
  description = "Terraform state bucket from 00-bootstrap. Used to read the network and security stacks."
  type        = string
}

variable "aurora_engine_version" {
  description = "Aurora MySQL version that supports Global Database. List options with: aws rds describe-db-engine-versions --engine aurora-mysql --query 'DBEngineVersions[?SupportsGlobalDatabases].EngineVersion'"
  type        = string
  default     = "8.0.mysql_aurora.3.08.2"
}

variable "aurora_instance_class" {
  description = "Global Database needs a memory-optimized class (db.r5/r6g/r7g and up)."
  type        = string
  default     = "db.r6g.large"
}

variable "primary_instance_count" {
  description = "Writer plus readers in Virginia. 2 gives a Multi-AZ failover target."
  type        = number
  default     = 2
}

variable "enable_secondary_region" {
  description = "Create the Oregon secondary cluster for cross-region reads and recovery."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Automated backup retention (the case study asks for 2 days)."
  type        = number
  default     = 2
}

variable "deletion_protection" {
  description = "Set false only when you intend to tear the database down."
  type        = bool
  default     = true
}

variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
