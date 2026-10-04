data "aws_iam_policy_document" "kms_primary" {
  statement {
    sid = "AccountRoot"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogs"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.primary_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.primary_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid = "CloudTrail"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }
}

data "aws_iam_policy_document" "kms_west" {
  statement {
    sid = "AccountRoot"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogs"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.secondary_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "primary" {
  description             = "${var.name_prefix} platform encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_primary.json

  tags = {
    Name = "${var.name_prefix}-primary"
  }
}

resource "aws_kms_alias" "primary" {
  name          = "alias/${var.name_prefix}-primary"
  target_key_id = aws_kms_key.primary.key_id
}

resource "aws_kms_key" "west" {
  provider                = aws.west
  description             = "${var.name_prefix} Oregon encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_west.json

  tags = {
    Name = "${var.name_prefix}-west"
  }
}

resource "aws_kms_alias" "west" {
  provider      = aws.west
  name          = "alias/${var.name_prefix}-west"
  target_key_id = aws_kms_key.west.key_id
}

resource "aws_ebs_encryption_by_default" "primary" {
  enabled = true
}

resource "aws_ebs_encryption_by_default" "west" {
  provider = aws.west
  enabled  = true
}

resource "aws_ebs_default_kms_key" "primary" {
  key_arn = aws_kms_key.primary.arn
}

resource "aws_ebs_default_kms_key" "west" {
  provider = aws.west
  key_arn  = aws_kms_key.west.arn
}
