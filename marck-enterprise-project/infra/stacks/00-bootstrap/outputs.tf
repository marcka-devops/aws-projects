output "state_bucket" {
  description = "Pass to every other stack: terraform init -backend-config=\"bucket=<this>\""
  value       = aws_s3_bucket.state.id
}

output "github_plan_role_arn" {
  description = "Set as the GitHub repository variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "github_apply_role_arn" {
  description = "Set as the GitHub repository variable AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.apply.arn
}

output "github_oidc_provider_arn" {
  value = local.oidc_provider_arn
}
