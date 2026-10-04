data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "platform" {
  for_each = toset([
    "assets",
    "www",
    "telemetry",
    "cloudtrail",
    "deploy",
    "terraform-state",
  ])

  bucket = "${var.name_prefix}-${each.key}"

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}

resource "aws_s3_bucket_versioning" "platform" {
  for_each = aws_s3_bucket.platform

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "platform" {
  for_each = aws_s3_bucket.platform

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "platform" {
  for_each = aws_s3_bucket.platform

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.primary.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.platform["assets"].id

  rule {
    id     = "expire-after-75-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 75
    }

    noncurrent_version_expiration {
      noncurrent_days = 75
    }
  }
}

resource "aws_s3_object" "www_index" {
  bucket       = aws_s3_bucket.platform["www"].id
  key          = "index.html"
  content_type = "text/html"
  content      = "<!doctype html><title>${var.name_prefix}</title><h1>${var.name_prefix}</h1>"
}

resource "aws_s3_object" "www_error" {
  bucket       = aws_s3_bucket.platform["www"].id
  key          = "error.html"
  content_type = "text/html"
  content      = "<!doctype html><title>${var.name_prefix}</title><h1>This site is only available at www.${var.domain_name}</h1>"
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.platform["cloudtrail"].arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.platform["cloudtrail"].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.platform["cloudtrail"].id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

data "aws_iam_policy_document" "www" {
  statement {
    sid       = "CloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.platform["www"].arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.www.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "www" {
  bucket = aws_s3_bucket.platform["www"].id
  policy = data.aws_iam_policy_document.www.json
}
