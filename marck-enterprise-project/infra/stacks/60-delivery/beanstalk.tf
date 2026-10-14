# AWS DevOps case study, task 5, and Automation case study, tasks 1-2:
# a PHP Elastic Beanstalk environment that receives the same release as the last pipeline stage.

data "aws_elastic_beanstalk_solution_stack" "php" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running PHP 8\\.(.*)$"
}

data "aws_iam_policy_document" "beanstalk_service_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "beanstalk_service" {
  name               = "${var.project}-beanstalk-service"
  assume_role_policy = data.aws_iam_policy_document.beanstalk_service_assume.json
}

resource "aws_iam_role_policy_attachment" "beanstalk_service" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy",
  ])
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "beanstalk_instance" {
  name               = "${var.project}-beanstalk-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "beanstalk_instance" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.beanstalk_instance.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "beanstalk" {
  name = "${var.project}-beanstalk-instance"
  role = aws_iam_role.beanstalk_instance.name
}

resource "aws_elastic_beanstalk_application" "web" {
  name        = "${var.project}-web"
  description = "Marck Enterprise PHP site (pipeline stage 3)"

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 20
    delete_source_from_s3 = true
  }
}

locals {
  beanstalk_settings = [
    { namespace = "aws:ec2:vpc", name = "VPCId", value = local.net.prod.vpc_id },
    { namespace = "aws:ec2:vpc", name = "Subnets", value = join(",", local.net.prod.subnet_ids["web"]) },
    { namespace = "aws:ec2:vpc", name = "AssociatePublicIpAddress", value = "true" },
    { namespace = "aws:ec2:instances", name = "InstanceTypes", value = var.beanstalk_instance_type },
    { namespace = "aws:autoscaling:launchconfiguration", name = "IamInstanceProfile", value = aws_iam_instance_profile.beanstalk.name },
    { namespace = "aws:autoscaling:launchconfiguration", name = "DisableIMDSv1", value = "true" },
    { namespace = "aws:elasticbeanstalk:environment", name = "EnvironmentType", value = "SingleInstance" },
    { namespace = "aws:elasticbeanstalk:environment", name = "ServiceRole", value = aws_iam_role.beanstalk_service.arn },
    { namespace = "aws:elasticbeanstalk:healthreporting:system", name = "SystemType", value = "enhanced" },
    { namespace = "aws:elasticbeanstalk:managedactions", name = "ManagedActionsEnabled", value = "true" },
    { namespace = "aws:elasticbeanstalk:managedactions", name = "PreferredStartTime", value = "Sun:06:00" },
    { namespace = "aws:elasticbeanstalk:managedactions:platformupdate", name = "UpdateLevel", value = "minor" },
    { namespace = "aws:elasticbeanstalk:cloudwatch:logs", name = "StreamLogs", value = "true" },
    { namespace = "aws:elasticbeanstalk:cloudwatch:logs", name = "RetentionInDays", value = "30" },
  ]
}

resource "aws_elastic_beanstalk_environment" "web" {
  name                = "${var.project}-php"
  application         = aws_elastic_beanstalk_application.web.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.php.name
  tier                = "WebServer"

  dynamic "setting" {
    for_each = local.beanstalk_settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
    }
  }

  # The pipeline deploys new versions; Terraform only owns the environment's settings.
  lifecycle {
    ignore_changes = [solution_stack_name]
  }
}
