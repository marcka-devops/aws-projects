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
  account_id    = data.aws_caller_identity.current.account_id
  template_path = "${path.module}/../../cloudformation/dev-test-stack.yaml"
  template_key  = "templates/dev-test-stack.yaml"
}
