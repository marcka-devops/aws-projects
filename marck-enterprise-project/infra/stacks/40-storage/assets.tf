# S3 Versioning case study, tasks 1-3, and the Automation case study's Lambda trigger.
#   1. Store any amount of data, retrievable from anywhere: S3 with HTTPS-only access.
#      Files are shared on demand with pre-signed URLs, so the bucket itself never goes public.
#   2. Delete data automatically after 75 days: lifecycle rule.
#   3. Recover an older version of a file: versioning (see docs/runbooks/restore-s3-version.md).

resource "aws_s3_bucket" "assets" {
  bucket = "${var.project}-assets-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "delete-after-${var.asset_expiration_days}-days"
    status = "Enabled"
    filter {}

    expiration {
      days = var.asset_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.asset_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

data "aws_iam_policy_document" "assets_tls" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_tls.json
}

# ---------------------------------------------------------------------------
# Lambda on object creation
# ---------------------------------------------------------------------------
data "archive_file" "on_upload" {
  type        = "zip"
  source_dir  = "${path.module}/../../../functions/s3_object_created"
  output_path = "${path.module}/.build/s3_object_created.zip"
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

resource "aws_iam_role" "on_upload" {
  name               = "${var.project}-s3-object-created"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "on_upload_logs" {
  role       = aws_iam_role.on_upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "on_upload" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }
}

resource "aws_iam_role_policy" "on_upload" {
  name   = "tag-uploads"
  role   = aws_iam_role.on_upload.id
  policy = data.aws_iam_policy_document.on_upload.json
}

resource "aws_cloudwatch_log_group" "on_upload" {
  name              = "/aws/lambda/${var.project}-s3-object-created"
  retention_in_days = 30
}

resource "aws_lambda_function" "on_upload" {
  function_name    = "${var.project}-s3-object-created"
  role             = aws_iam_role.on_upload.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.on_upload.output_path
  source_code_hash = data.archive_file.on_upload.output_base64sha256
  timeout          = 30
  memory_size      = 128

  depends_on = [aws_cloudwatch_log_group.on_upload]
}

resource "aws_lambda_permission" "assets" {
  statement_id   = "AllowAssetsBucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.on_upload.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.assets.arn
  source_account = local.account_id
}

resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.on_upload.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.assets]
}

resource "aws_cloudwatch_metric_alarm" "on_upload_errors" {
  alarm_name          = "${var.project}-s3-object-created-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.on_upload.function_name }
  alarm_actions       = [local.alerts]
}
