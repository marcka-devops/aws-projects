data "archive_file" "on_upload" {
  type        = "zip"
  source_file = "${path.module}/files/lambda/on_upload.py"
  output_path = "${path.module}/files/lambda/on_upload.zip"
}

data "archive_file" "telemetry" {
  type        = "zip"
  source_file = "${path.module}/files/lambda/telemetry.py"
  output_path = "${path.module}/files/lambda/telemetry.zip"
}

resource "aws_security_group" "lambda" {
  name_prefix = "${var.name_prefix}-lambda-"
  description = "Telemetry function reaching Aurora and the VPC endpoints"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-lambda" }
}

resource "aws_vpc_security_group_egress_rule" "lambda_https" {
  security_group_id = aws_security_group.lambda.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lambda_mysql" {
  security_group_id            = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_lambda" {
  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.lambda.id
}

resource "aws_cloudwatch_log_group" "on_upload" {
  name              = "/aws/lambda/${var.name_prefix}-on-upload"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.primary.arn
}

resource "aws_cloudwatch_log_group" "telemetry" {
  name              = "/aws/lambda/${var.name_prefix}-telemetry"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.primary.arn
}

resource "aws_lambda_function" "on_upload" {
  function_name    = "${var.name_prefix}-on-upload"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "on_upload.handler"
  filename         = data.archive_file.on_upload.output_path
  source_code_hash = data.archive_file.on_upload.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.on_upload]
}

resource "aws_lambda_function" "telemetry" {
  function_name    = "${var.name_prefix}-telemetry"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "telemetry.handler"
  filename         = data.archive_file.telemetry.output_path
  source_code_hash = data.archive_file.telemetry.output_base64sha256

  environment {
    variables = {
      TELEMETRY_BUCKET = aws_s3_bucket.platform["telemetry"].id
      AURORA_SECRET    = aws_secretsmanager_secret.aurora.arn
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.production["app1_a"].id, aws_subnet.production["app1_b"].id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [aws_cloudwatch_log_group.telemetry]
}

resource "aws_lambda_permission" "assets" {
  statement_id  = "AllowAssetsBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.on_upload.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.platform["assets"].arn
}

resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.platform["assets"].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.on_upload.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.assets]
}

resource "aws_lambda_event_source_mapping" "telemetry" {
  event_source_arn  = aws_kinesis_stream.telemetry.arn
  function_name     = aws_lambda_function.telemetry.arn
  starting_position = "LATEST"
}
