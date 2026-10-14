# IAM case study.
#   1a. A user that can sign in to the console.
#   1b. A group that can only launch and stop EC2 instances.
#   2a. Let that user create VPCs, subnets, NACLs and security groups.
#   2b. Let that user create RDS instances.
#   2c. Protect the account: MFA, password policy, permissions boundary, region lock,
#       CloudTrail, GuardDuty and Access Analyzer (see audit.tf).

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# ---------------------------------------------------------------------------
# Groups and policies
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_launch_stop" {
  statement {
    sid       = "ReadForConsole"
    actions   = ["ec2:Describe*", "ec2:GetConsoleOutput", "ec2:GetInstanceTypesFromInstanceRequirements"]
    resources = ["*"]
  }

  statement {
    sid       = "LaunchStartStop"
    actions   = ["ec2:RunInstances", "ec2:StartInstances", "ec2:StopInstances"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid       = "TagOnLaunchOnly"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances"]
    }
  }

  statement {
    sid       = "NeverTerminate"
    effect    = "Deny"
    actions   = ["ec2:TerminateInstances"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "network_builder" {
  statement {
    sid = "CreateNetworkResources"
    actions = [
      "ec2:CreateVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateNetworkAcl",
      "ec2:CreateNetworkAclEntry",
      "ec2:ReplaceNetworkAclEntry",
      "ec2:ReplaceNetworkAclAssociation",
      "ec2:CreateSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:CreateTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

data "aws_iam_policy_document" "rds_builder" {
  statement {
    sid       = "ReadRds"
    actions   = ["rds:Describe*", "rds:ListTagsForResource", "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeAvailabilityZones"]
    resources = ["*"]
  }

  statement {
    sid       = "CreateSubnetGroups"
    actions   = ["rds:CreateDBSubnetGroup", "rds:AddTagsToResource"]
    resources = ["*"]
  }

  # Small, encrypted instances only.
  statement {
    sid       = "CreateSmallEncryptedInstances"
    actions   = ["rds:CreateDBInstance"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "rds:DatabaseClass"
      values   = ["db.t3.*", "db.t4g.*"]
    }
    condition {
      test     = "Bool"
      variable = "rds:StorageEncrypted"
      values   = ["true"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

# Standard "deny everything until MFA" pattern. Users can still set up their own MFA device.
data "aws_iam_policy_document" "require_mfa" {
  statement {
    sid = "ManageOwnCredentialsAndMfa"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:GetLoginProfile",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:user/$${aws:username}",
      "arn:aws:iam::${local.account_id}:mfa/*",
    ]
  }

  statement {
    sid    = "DenyAllWithoutMfa"
    effect = "Deny"
    not_actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:GetLoginProfile",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
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

locals {
  groups = {
    ec2-operators    = data.aws_iam_policy_document.ec2_launch_stop.json
    network-builders = data.aws_iam_policy_document.network_builder.json
    rds-builders     = data.aws_iam_policy_document.rds_builder.json
    mfa-required     = data.aws_iam_policy_document.require_mfa.json
  }
}

resource "aws_iam_policy" "group" {
  for_each = local.groups

  name   = "${var.project}-${each.key}"
  policy = each.value
}

resource "aws_iam_group" "this" {
  for_each = local.groups
  name     = "${var.project}-${each.key}"
}

resource "aws_iam_group_policy_attachment" "this" {
  for_each = local.groups

  group      = aws_iam_group.this[each.key].name
  policy_arn = aws_iam_policy.group[each.key].arn
}

# Developers launch test stacks from Service Catalog without needing admin rights (see 70-self-service).
resource "aws_iam_group" "developers" {
  name = "${var.project}-developers"
}

resource "aws_iam_group_policy_attachment" "developers_catalog" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AWSServiceCatalogEndUserFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.group["mfa-required"].arn
}

# ---------------------------------------------------------------------------
# The ops user. A permissions boundary caps what any future policy can grant.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "CeilingForOpsUser"
    actions   = ["ec2:*", "rds:*", "elasticloadbalancing:Describe*", "cloudwatch:Get*", "cloudwatch:List*", "cloudwatch:Describe*", "servicecatalog:*", "cloudformation:Describe*", "cloudformation:List*"]
    resources = ["*"]
  }

  statement {
    sid = "SelfService"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:GetLoginProfile",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "sts:GetSessionToken",
    ]
    resources = ["*"]
  }

  # Even if someone later attaches AdministratorAccess, the boundary blocks privilege escalation.
  statement {
    sid    = "NoPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:CreateAccessKey",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:Attach*",
      "iam:Put*Policy",
      "iam:PassRole",
      "iam:DeleteUserPermissionsBoundary",
      "iam:DeleteRolePermissionsBoundary",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name   = "${var.project}-ops-boundary"
  policy = data.aws_iam_policy_document.boundary.json
}

resource "aws_iam_user" "ops" {
  name                 = var.ops_user_name
  permissions_boundary = aws_iam_policy.boundary.arn
  force_destroy        = true
}

resource "aws_iam_user_group_membership" "ops" {
  user = aws_iam_user.ops.name
  groups = [
    aws_iam_group.this["ec2-operators"].name,
    aws_iam_group.this["network-builders"].name,
    aws_iam_group.this["rds-builders"].name,
    aws_iam_group.this["mfa-required"].name,
  ]
}

resource "aws_iam_user_login_profile" "ops" {
  count = var.create_console_login ? 1 : 0

  user                    = aws_iam_user.ops.name
  password_length         = 20
  password_reset_required = true
  pgp_key                 = var.console_password_pgp_key

  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}
