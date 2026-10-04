data "tls_certificate" "gitlab" {
  url = var.gitlab_url
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = var.gitlab_url
  client_id_list  = [var.gitlab_url]
  thumbprint_list = [data.tls_certificate.gitlab.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "Regions"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.primary_region, var.secondary_region]
    }
  }

  statement {
    sid = "GlobalServices"
    actions = [
      "iam:*",
      "sts:*",
      "route53:*",
      "cloudfront:*",
      "globalaccelerator:*",
      "support:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyUsersKeysAndOrganizations"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "organizations:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name   = "${var.name_prefix}-boundary"
  policy = data.aws_iam_policy_document.boundary.json
}

data "aws_iam_policy_document" "gitlab_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gitlab.arn]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(var.gitlab_url, "https://", "")}:sub"
      values   = var.gitlab_oidc_subjects
    }
  }
}

data "aws_iam_policy_document" "platform" {
  statement {
    sid = "PlatformServices"
    actions = [
      "acm:*",
      "autoscaling:*",
      "cloudformation:*",
      "cloudfront:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "codedeploy:*",
      "dynamodb:*",
      "ec2:*",
      "elasticache:*",
      "elasticbeanstalk:*",
      "elasticloadbalancing:*",
      "fsx:*",
      "globalaccelerator:*",
      "imagebuilder:*",
      "kinesis:*",
      "kms:*",
      "lambda:*",
      "logs:*",
      "rds:*",
      "route53:*",
      "s3:*",
      "secretsmanager:*",
      "ssm:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "PassRole"
    actions = [
      "iam:PassRole",
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:AttachGroupPolicy",
      "iam:DetachGroupPolicy",
      "iam:PutGroupPolicy",
      "iam:CreateGroup",
      "iam:DeleteGroup",
      "iam:GetGroup",
      "iam:UpdateGroup",
      "iam:ListGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "platform" {
  name   = "${var.name_prefix}-platform"
  policy = data.aws_iam_policy_document.platform.json
}

resource "aws_iam_role" "platform" {
  name                 = "${var.name_prefix}-platform"
  assume_role_policy   = data.aws_iam_policy_document.gitlab_assume.json
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy_attachment" "platform" {
  role       = aws_iam_role.platform.name
  policy_arn = aws_iam_policy.platform.arn
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "Deploy"
    actions = [
      "codedeploy:*",
      "elasticbeanstalk:CreateApplicationVersion",
      "elasticbeanstalk:UpdateEnvironment",
      "elasticbeanstalk:Describe*",
      "autoscaling:Describe*",
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = "${var.name_prefix}-deploy"
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role" "deploy" {
  name                 = "${var.name_prefix}-deploy"
  assume_role_policy   = data.aws_iam_policy_document.gitlab_assume.json
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
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

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "instance_deploy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.platform["deploy"].arn,
      "${aws_s3_bucket.platform["deploy"].arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "instance_deploy" {
  name   = "deploy-bucket"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance_deploy.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

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
  name               = "${var.name_prefix}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_iam_role" "imagebuilder" {
  name               = "${var.name_prefix}-imagebuilder"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "imagebuilder" {
  for_each = toset([
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.imagebuilder.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "imagebuilder" {
  name = "${var.name_prefix}-imagebuilder"
  role = aws_iam_role.imagebuilder.name
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
  name               = "${var.name_prefix}-beanstalk-service"
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

resource "aws_iam_role" "beanstalk_instance" {
  name               = "${var.name_prefix}-beanstalk-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "beanstalk_instance" {
  role       = aws_iam_role.beanstalk_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "beanstalk" {
  name = "${var.name_prefix}-beanstalk"
  role = aws_iam_role.beanstalk_instance.name
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.platform["assets"].arn,
      "${aws_s3_bucket.platform["assets"].arn}/*",
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.platform["telemetry"].arn,
      "${aws_s3_bucket.platform["telemetry"].arn}/*",
    ]
  }

  statement {
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:SubscribeToShard",
    ]
    resources = [aws_kinesis_stream.telemetry.arn]
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.aurora.arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "data-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}
