resource "aws_iam_user" "operator" {
  name                 = "${var.name_prefix}-operator"
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_group" "platform" {
  name = "${var.name_prefix}-platform-operators"
}

resource "aws_iam_user_group_membership" "operator" {
  user   = aws_iam_user.operator.name
  groups = [aws_iam_group.platform.name]
}

data "aws_iam_policy_document" "operator_ec2" {
  statement {
    sid = "Describe"
    actions = [
      "ec2:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Lifecycle"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
    ]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.primary_region, var.secondary_region]
    }
  }
}

data "aws_iam_policy_document" "operator_network" {
  statement {
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateNetworkAcl",
      "ec2:DeleteNetworkAcl",
      "ec2:CreateNetworkAclEntry",
      "ec2:DeleteNetworkAclEntry",
      "ec2:ReplaceNetworkAclAssociation",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "operator_rds" {
  statement {
    actions = [
      "rds:CreateDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:Describe*",
      "rds:AddTagsToResource",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "operator_mfa" {
  statement {
    sid    = "DenyWithoutMfa"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetSessionToken",
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "operator_ec2" {
  name   = "${var.name_prefix}-operator-ec2"
  policy = data.aws_iam_policy_document.operator_ec2.json
}

resource "aws_iam_policy" "operator_network" {
  name   = "${var.name_prefix}-operator-network"
  policy = data.aws_iam_policy_document.operator_network.json
}

resource "aws_iam_policy" "operator_rds" {
  name   = "${var.name_prefix}-operator-rds"
  policy = data.aws_iam_policy_document.operator_rds.json
}

resource "aws_iam_policy" "operator_mfa" {
  name   = "${var.name_prefix}-operator-mfa"
  policy = data.aws_iam_policy_document.operator_mfa.json
}

resource "aws_iam_group_policy_attachment" "operator" {
  for_each = {
    ec2     = aws_iam_policy.operator_ec2.arn
    network = aws_iam_policy.operator_network.arn
    rds     = aws_iam_policy.operator_rds.arn
    mfa     = aws_iam_policy.operator_mfa.arn
  }

  group      = aws_iam_group.platform.name
  policy_arn = each.value
}
