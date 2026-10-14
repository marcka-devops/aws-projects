# AWS DevOps case study, task 3: CodeDeploy deployments for QA and production on EC2.
#   QA         -> the "web" instance in the development VPC (tag DeployGroup=qa)
#   Production -> the Virginia Auto Scaling group, one instance at a time behind the load balancer
#   Standby    -> the Oregon Auto Scaling group, so a regional failover serves the same release

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.project}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# The groups use launch templates; CodeDeploy needs to pass the instance role when it relaunches.
resource "aws_iam_role_policy" "codedeploy_launch_template" {
  name = "launch-template"
  role = aws_iam_role.codedeploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:RunInstances", "ec2:CreateTags"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${local.account_id}:role/${local.compute.instance_role_name}"
      },
    ]
  })
}

# ------------------------------- Virginia ----------------------------------
resource "aws_codedeploy_app" "web" {
  name             = "${var.project}-web"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "qa" {
  app_name               = aws_codedeploy_app.web.name
  deployment_group_name  = "qa"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "DeployGroup"
      type  = "KEY_AND_VALUE"
      value = "qa"
    }
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_codedeploy_deployment_group" "production" {
  app_name               = aws_codedeploy_app.web.name
  deployment_group_name  = "production"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  autoscaling_groups     = [local.compute.asg_east_name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info {
      name = local.compute.target_group_east_name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# -------------------------------- Oregon -----------------------------------
resource "aws_codedeploy_app" "web_west" {
  count    = var.deploy_to_oregon ? 1 : 0
  provider = aws.west

  name             = "${var.project}-web"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "standby" {
  count    = var.deploy_to_oregon ? 1 : 0
  provider = aws.west

  app_name               = aws_codedeploy_app.web_west[0].name
  deployment_group_name  = "standby"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  autoscaling_groups     = [local.compute.asg_west_name]

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
