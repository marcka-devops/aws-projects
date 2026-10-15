data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "network/terraform.tfstate"
    region = var.primary_region
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "security/terraform.tfstate"
    region = var.primary_region
  }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "compute/terraform.tfstate"
    region = var.primary_region
  }
}

data "aws_caller_identity" "current" {}

locals {
  net        = data.terraform_remote_state.network.outputs
  compute    = data.terraform_remote_state.compute.outputs
  alerts     = data.terraform_remote_state.security.outputs.alerts_topic_arn
  account_id = data.aws_caller_identity.current.account_id

  # Must match local.artifact_bucket in 50-compute, which grants the instances read access.
  artifact_bucket      = "${var.project}-artifacts-${local.account_id}"
  artifact_bucket_west = "${var.project}-artifacts-${local.account_id}-west"

  # Path from the repository root to app/, used by CodeBuild and the pipeline trigger.
  app_dir = var.project_dir == "" ? "app" : "${var.project_dir}/app"
}
