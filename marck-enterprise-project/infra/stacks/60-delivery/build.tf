# CodeBuild projects: build-and-test, and the QA smoke test that gates production.

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.primary_region}:${local.account_id}:log-group:/codebuild/${var.project}*"]
  }

  statement {
    sid     = "Artifacts"
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketLocation"]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid       = "Reports"
    actions   = ["codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases"]
    resources = ["arn:aws:codebuild:${var.primary_region}:${local.account_id}:report-group/${var.project}-*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "build"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_cloudwatch_log_group" "build" {
  name              = "/codebuild/${var.project}-build"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "smoke" {
  name              = "/codebuild/${var.project}-qa-smoke"
  retention_in_days = 30
}

resource "aws_codebuild_project" "build" {
  name          = "${var.project}-build"
  description   = "Lint, test and package the website"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  source {
    type      = "CODEPIPELINE"
    buildspec = "${local.app_dir}/buildspec.yml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "APP_DIR"
      value = local.app_dir
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
}

resource "aws_codebuild_project" "qa_smoke" {
  name          = "${var.project}-qa-smoke"
  description   = "Smoke test the QA instance; production waits for this"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10

  source {
    type      = "CODEPIPELINE"
    buildspec = "${local.app_dir}/buildspec-smoke.yml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "QA_URL"
      value = "http://${coalesce(local.compute.qa_instance_public_dns, "qa-instance-disabled.invalid")}"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.smoke.name
    }
  }
}
