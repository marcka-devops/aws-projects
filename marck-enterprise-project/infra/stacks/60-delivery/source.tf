# AWS DevOps case study, tasks 1-2: the website lives in GitHub and is migrated to CodeCommit.
# GitHub stays the place people work. The mirror workflow (.github/workflows/codecommit-mirror.yml)
# pushes main to CodeCommit through this OIDC role, and CodeCommit is the pipeline source.

resource "aws_codecommit_repository" "app" {
  count = var.source_provider == "codecommit" ? 1 : 0

  repository_name = var.project
  description     = "Marck Enterprise, mirrored from github.com/${var.github_owner}/${var.github_repo}"
  default_branch  = var.branch
}

resource "aws_codestarconnections_connection" "github" {
  count = var.source_provider == "github" ? 1 : 0

  # Created as PENDING. Finish the GitHub handshake once in the console:
  # Developer Tools > Settings > Connections > Update pending connection.
  name          = "${var.project}-github"
  provider_type = "GitHub"
}

# OIDC role the GitHub mirror job assumes. Only the main branch of this repository can push.
data "aws_iam_openid_connect_provider" "github" {
  count = var.source_provider == "codecommit" ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "mirror_trust" {
  count = var.source_provider == "codecommit" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.branch}"]
    }
  }
}

resource "aws_iam_role" "mirror" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name               = "${var.project}-github-mirror"
  description        = "GitHub Actions: push main to CodeCommit"
  assume_role_policy = data.aws_iam_policy_document.mirror_trust[0].json
}

data "aws_iam_policy_document" "mirror" {
  count = var.source_provider == "codecommit" ? 1 : 0

  statement {
    actions   = ["codecommit:GitPull", "codecommit:GitPush"]
    resources = [aws_codecommit_repository.app[0].arn]
  }
}

resource "aws_iam_role_policy" "mirror" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name   = "push-to-codecommit"
  role   = aws_iam_role.mirror[0].id
  policy = data.aws_iam_policy_document.mirror[0].json
}

# CodeCommit sources need an EventBridge rule to start the pipeline on push.
resource "aws_cloudwatch_event_rule" "codecommit_push" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name        = "${var.project}-codecommit-push"
  description = "Start the pipeline when ${var.branch} changes in CodeCommit"
  event_pattern = jsonencode({
    source        = ["aws.codecommit"]
    "detail-type" = ["CodeCommit Repository State Change"]
    resources     = [aws_codecommit_repository.app[0].arn]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = [var.branch]
    }
  })
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name               = "${var.project}-start-pipeline"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

resource "aws_iam_role_policy" "events" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name = "start-pipeline"
  role = aws_iam_role.events[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codepipeline:StartPipelineExecution"
      Resource = aws_codepipeline.app.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "codecommit_push" {
  count = var.source_provider == "codecommit" ? 1 : 0

  rule     = aws_cloudwatch_event_rule.codecommit_push[0].name
  arn      = aws_codepipeline.app.arn
  role_arn = aws_iam_role.events[0].arn
}
