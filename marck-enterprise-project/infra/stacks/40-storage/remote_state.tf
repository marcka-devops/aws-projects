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

data "aws_caller_identity" "current" {}

locals {
  net        = data.terraform_remote_state.network.outputs
  alerts     = data.terraform_remote_state.security.outputs.alerts_topic_arn
  account_id = data.aws_caller_identity.current.account_id
  domain     = local.net.domain_name
  zone_id    = local.net.zone_id
  www        = "www.${local.net.domain_name}"
}
