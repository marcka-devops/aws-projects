output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "developers_group_arn" {
  value = aws_iam_group.developers.arn
}

output "ops_user_name" {
  value = aws_iam_user.ops.name
}

output "console_sign_in_url" {
  value = "https://${local.account_id}.signin.aws.amazon.com/console"
}

output "ops_initial_password" {
  description = "Plain-text first password (only when no PGP key is set). Read with: terraform output -raw ops_initial_password"
  value       = var.create_console_login && var.console_password_pgp_key == null ? aws_iam_user_login_profile.ops[0].password : null
  sensitive   = true
}

output "ops_initial_password_encrypted" {
  description = "PGP-encrypted first password, when console_password_pgp_key is set."
  value       = var.create_console_login && var.console_password_pgp_key != null ? aws_iam_user_login_profile.ops[0].encrypted_password : null
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}
