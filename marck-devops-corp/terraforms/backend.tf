# Local state until the bucket from s3_bucket.tf exists.
# Then uncomment this block and run: terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket         = "marck-devops-corp-terraform-state"
#     key            = "platform/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "marck-devops-corp-terraform-locks"
#     encrypt        = true
#   }
# }
