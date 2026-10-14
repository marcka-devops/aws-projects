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

variable "source_provider" {
  description = <<-EOT
    Where CodePipeline reads the code:
      codecommit - an AWS CodeCommit repository, kept in sync from GitHub by the
                   mirror workflow (the DevOps case study's "migrate GitHub to CodeCommit")
      github     - GitHub directly, through an AWS CodeConnections connection
  EOT
  type        = string
  default     = "codecommit"

  validation {
    condition     = contains(["codecommit", "github"], var.source_provider)
    error_message = "source_provider must be codecommit or github."
  }
}

variable "github_owner" {
  description = "GitHub user or organization."
  type        = string
}

variable "github_repo" {
  description = "Repository that holds this project."
  type        = string
  default     = "aws-projects"
}

variable "project_dir" {
  description = "Folder of this project inside the repository. Empty when the project is the repository root."
  type        = string
  default     = "marck-enterprise-project"
}

variable "branch" {
  type    = string
  default = "main"
}

variable "require_manual_approval" {
  description = "Add a human approval between QA and production."
  type        = bool
  default     = false
}

variable "deploy_to_oregon" {
  description = "Deploy each release to the Oregon standby fleet alongside Virginia."
  type        = bool
  default     = true
}

variable "beanstalk_instance_type" {
  type    = string
  default = "t3.micro"
}
