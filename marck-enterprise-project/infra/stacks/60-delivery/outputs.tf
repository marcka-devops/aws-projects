output "pipeline_name" {
  value = aws_codepipeline.app.name
}

output "pipeline_console_url" {
  value = "https://${var.primary_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.app.name}/view"
}

output "codecommit_clone_url" {
  value = var.source_provider == "codecommit" ? aws_codecommit_repository.app[0].clone_url_http : null
}

output "github_mirror_role_arn" {
  description = "Set as the GitHub repository variable AWS_MIRROR_ROLE_ARN."
  value       = var.source_provider == "codecommit" ? aws_iam_role.mirror[0].arn : null
}

output "github_connection_arn" {
  description = "Approve this pending connection once in the AWS console."
  value       = var.source_provider == "github" ? aws_codestarconnections_connection.github[0].arn : null
}

output "beanstalk_url" {
  value = "http://${aws_elastic_beanstalk_environment.web.cname}"
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.id
}
