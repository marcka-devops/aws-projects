# AWS DevOps case study, task 4: the release pipeline.
#
#   Source -> Build -> QA -> QA-Verify -> [Approval] -> Production -> Beanstalk
#
# Each stage runs only when the stage before it succeeds, so production never receives
# a release that failed in QA.

data "aws_iam_policy_document" "pipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name               = "${var.project}-pipeline"
  assume_role_policy = data.aws_iam_policy_document.pipeline_assume.json
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    sid = "Artifacts"
    actions = [
      "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:PutObjectAcl",
      "s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*",
      aws_s3_bucket.artifacts_west.arn, "${aws_s3_bucket.artifacts_west.arn}/*",
    ]
  }

  dynamic "statement" {
    for_each = var.source_provider == "codecommit" ? [1] : []
    content {
      sid = "CodeCommitSource"
      actions = [
        "codecommit:GetBranch", "codecommit:GetCommit", "codecommit:GetRepository",
        "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus", "codecommit:CancelUploadArchive",
      ]
      resources = [aws_codecommit_repository.app[0].arn]
    }
  }

  dynamic "statement" {
    for_each = var.source_provider == "github" ? [1] : []
    content {
      sid       = "GitHubSource"
      actions   = ["codestar-connections:UseConnection", "codeconnections:UseConnection"]
      resources = [aws_codestarconnections_connection.github[0].arn]
    }
  }

  statement {
    sid       = "Build"
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
    resources = [aws_codebuild_project.build.arn, aws_codebuild_project.qa_smoke.arn]
  }

  statement {
    sid = "Deploy"
    actions = [
      "codedeploy:CreateDeployment", "codedeploy:GetApplication", "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment", "codedeploy:GetDeploymentConfig", "codedeploy:RegisterApplicationRevision",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "Notify"
    actions   = ["sns:Publish"]
    resources = [local.alerts]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "pipeline"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}

# The Elastic Beanstalk deploy action drives CloudFormation, Auto Scaling and EC2 on the pipeline's behalf.
resource "aws_iam_role_policy_attachment" "pipeline_beanstalk" {
  role       = aws_iam_role.pipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
}

resource "aws_codepipeline" "app" {
  name           = "${var.project}-release"
  role_arn       = aws_iam_role.pipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
    region   = var.primary_region
  }

  artifact_store {
    location = aws_s3_bucket.artifacts_west.bucket
    type     = "S3"
    region   = var.secondary_region
  }

  # ------------------------------- Source ----------------------------------
  stage {
    name = "Source"

    dynamic "action" {
      for_each = var.source_provider == "codecommit" ? [1] : []
      content {
        name             = "Source"
        category         = "Source"
        owner            = "AWS"
        provider         = "CodeCommit"
        version          = "1"
        output_artifacts = ["source"]
        configuration = {
          RepositoryName       = aws_codecommit_repository.app[0].repository_name
          BranchName           = var.branch
          PollForSourceChanges = "false"
          OutputArtifactFormat = "CODE_ZIP"
        }
      }
    }

    dynamic "action" {
      for_each = var.source_provider == "github" ? [1] : []
      content {
        name             = "Source"
        category         = "Source"
        owner            = "AWS"
        provider         = "CodeStarSourceConnection"
        version          = "1"
        output_artifacts = ["source"]
        configuration = {
          ConnectionArn    = aws_codestarconnections_connection.github[0].arn
          FullRepositoryId = "${var.github_owner}/${var.github_repo}"
          BranchName       = var.branch
          DetectChanges    = "false"
        }
      }
    }
  }

  # -------------------------------- Build ----------------------------------
  stage {
    name = "Build"
    action {
      name             = "LintTestPackage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["bundle"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  # --------------------------------- QA ------------------------------------
  stage {
    name = "QA"
    action {
      name            = "DeployToQA"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["bundle"]
      run_order       = 1
      configuration = {
        ApplicationName     = aws_codedeploy_app.web.name
        DeploymentGroupName = aws_codedeploy_deployment_group.qa.deployment_group_name
      }
    }

    action {
      name            = "SmokeTestQA"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      run_order       = 2
      configuration = {
        ProjectName = aws_codebuild_project.qa_smoke.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.require_manual_approval ? [1] : []
    content {
      name = "Approval"
      action {
        name     = "ApproveProduction"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        configuration = {
          NotificationArn = local.alerts
          CustomData      = "QA passed. Approve to release to production."
        }
      }
    }
  }

  # ----------------------------- Production --------------------------------
  stage {
    name = "Production"

    action {
      name            = "DeployVirginia"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["bundle"]
      region          = var.primary_region
      configuration = {
        ApplicationName     = aws_codedeploy_app.web.name
        DeploymentGroupName = aws_codedeploy_deployment_group.production.deployment_group_name
      }
    }

    dynamic "action" {
      for_each = var.deploy_to_oregon ? [1] : []
      content {
        name            = "DeployOregon"
        category        = "Deploy"
        owner           = "AWS"
        provider        = "CodeDeploy"
        version         = "1"
        input_artifacts = ["bundle"]
        region          = var.secondary_region
        configuration = {
          ApplicationName     = aws_codedeploy_app.web_west[0].name
          DeploymentGroupName = aws_codedeploy_deployment_group.standby[0].deployment_group_name
        }
      }
    }
  }

  # ------------------------------ Beanstalk --------------------------------
  stage {
    name = "Beanstalk"
    action {
      name            = "DeployBeanstalk"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["bundle"]
      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.web.name
        EnvironmentName = aws_elastic_beanstalk_environment.web.name
      }
    }
  }

  # GitHub source: start on pushes to main that touch the app.
  dynamic "trigger" {
    for_each = var.source_provider == "github" ? [1] : []
    content {
      provider_type = "CodeStarSourceConnection"
      git_configuration {
        source_action_name = "Source"
        push {
          branches {
            includes = [var.branch]
          }
          file_paths {
            includes = ["${local.app_dir}/**"]
          }
        }
      }
    }
  }
}

# Tell the team when a release fails.
resource "aws_cloudwatch_event_rule" "pipeline_failed" {
  name        = "${var.project}-release-failed"
  description = "Release pipeline execution failed"
  event_pattern = jsonencode({
    source        = ["aws.codepipeline"]
    "detail-type" = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.app.name]
      state    = ["FAILED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_failed" {
  rule = aws_cloudwatch_event_rule.pipeline_failed.name
  arn  = local.alerts

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
    }
    input_template = "\"Release pipeline <pipeline> failed (execution <execution>).\""
  }
}
