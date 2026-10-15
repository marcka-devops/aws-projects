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

data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "data/terraform.tfstate"
    region = var.primary_region
  }
}

data "aws_caller_identity" "current" {}

locals {
  net        = data.terraform_remote_state.network.outputs
  alerts     = data.terraform_remote_state.security.outputs.alerts_topic_arn
  db         = data.terraform_remote_state.data.outputs
  account_id = data.aws_caller_identity.current.account_id
  app_host   = "app.${local.net.domain_name}"

  # Created by 60-delivery. Named here so instances can read deployment bundles from it.
  artifact_bucket = "${var.project}-artifacts-${local.account_id}"
}
