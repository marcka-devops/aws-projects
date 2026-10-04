resource "aws_cloudwatch_log_group" "flow_primary" {
  name              = "/${var.name_prefix}/vpc-flow/primary"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.primary.arn
}

resource "aws_cloudwatch_log_group" "flow_west" {
  provider          = aws.west
  name              = "/${var.name_prefix}/vpc-flow/west"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.west.arn
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "write-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "production" {
  vpc_id          = aws_vpc.production.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_primary.arn
}

resource "aws_flow_log" "development" {
  vpc_id          = aws_vpc.development.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_primary.arn
}

resource "aws_flow_log" "test" {
  vpc_id          = aws_vpc.test.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_primary.arn
}

resource "aws_iam_role" "flow_logs_west" {
  provider           = aws.west
  name               = "${var.name_prefix}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
}

resource "aws_iam_role_policy" "flow_logs_west" {
  provider = aws.west
  name     = "write-logs"
  role     = aws_iam_role.flow_logs_west.id
  policy   = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "oregon" {
  provider        = aws.west
  vpc_id          = aws_vpc.oregon.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs_west.arn
  log_destination = aws_cloudwatch_log_group.flow_west.arn
}
