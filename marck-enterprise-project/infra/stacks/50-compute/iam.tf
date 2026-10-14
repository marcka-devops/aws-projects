# One instance role for every server: Session Manager, CloudWatch agent, CodeDeploy bundles,
# the Ansible playbooks, and the database secret.

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
  name               = "${var.project}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "instance" {
  statement {
    sid     = "ReadDeploymentBundlesAndPlaybooks"
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
    resources = [
      # <artifact bucket> in Virginia and <artifact bucket>-west in Oregon
      "arn:aws:s3:::${local.artifact_bucket}*",
      "arn:aws:s3:::${local.artifact_bucket}*/*",
      aws_s3_bucket.config.arn,
      "${aws_s3_bucket.config.arn}/*",
    ]
  }

  statement {
    sid       = "CodeDeployAgentInstaller"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::aws-codedeploy-*/*"]
  }

  statement {
    sid       = "ReadDatabaseSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:${local.account_id}:secret:${local.db.db_secret_name}-*"]
  }

  statement {
    sid       = "SendDeviceEvents"
    actions   = ["kinesis:PutRecord", "kinesis:PutRecords"]
    resources = [local.db.device_stream_arn]
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "app-access"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project}-instance"
  role = aws_iam_role.instance.name
}

resource "aws_key_pair" "admin" {
  count      = var.ssh_public_key == "" ? 0 : 1
  key_name   = "${var.project}-admin"
  public_key = var.ssh_public_key
}

locals {
  key_name = var.ssh_public_key == "" ? null : aws_key_pair.admin[0].key_name
}
