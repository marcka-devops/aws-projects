variable "project" {
  description = "Lowercase project slug used in resource names."
  type        = string
  default     = "marck-enterprise"
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository name, without the owner."
  type        = string
  default     = "aws-projects"
}

variable "create_github_oidc_provider" {
  description = "False if the account already has the token.actions.githubusercontent.com provider."
  type        = bool
  default     = true
}
