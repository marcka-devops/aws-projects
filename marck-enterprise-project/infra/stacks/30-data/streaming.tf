# Near real-time analysis (Database Architecture case study, task 3).
# Devices put events on a Kinesis stream. A Lambda function reads them in small batches,
# writes per-branch summaries to S3 and emits CloudWatch metrics for dashboards.

resource "aws_kinesis_stream" "device_events" {
  name             = "${var.project}-device-events"
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = "alias/aws/kinesis"

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

# -------------------------- analytics bucket -------------------------------
resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project}-analytics-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "analytics" {
  bucket                  = aws_s3_bucket.analytics.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id
  rule {
    id     = "expire-summaries"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
  }
}

# ------------------------------ consumer -----------------------------------
data "archive_file" "telemetry" {
  type        = "zip"
  source_dir  = "${path.module}/../../../functions/device_telemetry"
  output_path = "${path.module}/.build/device_telemetry.zip"
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

resource "aws_iam_role" "telemetry" {
  name               = "${var.project}-device-telemetry"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "telemetry_kinesis" {
  role       = aws_iam_role.telemetry.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
}

data "aws_iam_policy_document" "telemetry" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.analytics.arn}/summaries/*"]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["kinesis.${var.primary_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "telemetry" {
  name   = "write-summaries"
  role   = aws_iam_role.telemetry.id
  policy = data.aws_iam_policy_document.telemetry.json
}

resource "aws_cloudwatch_log_group" "telemetry" {
  name              = "/aws/lambda/${var.project}-device-telemetry"
  retention_in_days = 30
}

resource "aws_lambda_function" "telemetry" {
  function_name    = "${var.project}-device-telemetry"
  role             = aws_iam_role.telemetry.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.telemetry.output_path
  source_code_hash = data.archive_file.telemetry.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      ANALYTICS_BUCKET = aws_s3_bucket.analytics.id
      METRIC_NAMESPACE = "MarckEnterprise/Devices"
    }
  }

  depends_on = [aws_cloudwatch_log_group.telemetry]
}

resource "aws_lambda_event_source_mapping" "telemetry" {
  event_source_arn                   = aws_kinesis_stream.device_events.arn
  function_name                      = aws_lambda_function.telemetry.arn
  starting_position                  = "LATEST"
  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
  bisect_batch_on_function_error     = true
  maximum_retry_attempts             = 3
  function_response_types            = ["ReportBatchItemFailures"]
}

resource "aws_cloudwatch_metric_alarm" "telemetry_errors" {
  alarm_name          = "${var.project}-device-telemetry-errors"
  alarm_description   = "The telemetry consumer failed in the last 5 minutes."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.telemetry.function_name }
  alarm_actions       = [local.alerts]
}
