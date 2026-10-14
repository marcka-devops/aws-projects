# Multi-Tier Architecture case study, proposal part:
#   1. Developers test code without waiting for system admins: they launch the three-tier
#      test stack themselves from AWS Service Catalog.
#   2. Deleting that stack keeps the RDS instance: the template retains it (DeletionPolicy: Retain).
# The launch role does the provisioning, so developers need no EC2, RDS or VPC permissions.

# ---------------------------------------------------------------------------
# Template storage
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "catalog" {
  bucket = "${var.project}-catalog-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "catalog" {
  bucket                  = aws_s3_bucket.catalog.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "catalog" {
  bucket = aws_s3_bucket.catalog.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "template" {
  bucket = aws_s3_bucket.catalog.id
  key    = local.template_key
  source = local.template_path
  etag   = filemd5(local.template_path)
}

# ---------------------------------------------------------------------------
# Portfolio and product
# ---------------------------------------------------------------------------
resource "aws_servicecatalog_portfolio" "developers" {
  name          = "Marck Enterprise developer self-service"
  description   = "Environments developers can launch without help from operations"
  provider_name = "Marck Enterprise platform team"
}

resource "aws_servicecatalog_product" "test_stack" {
  name        = "Three-tier test environment"
  owner       = "Marck Enterprise platform team"
  description = "Web, app and MySQL tiers for testing code. The database is kept when the environment is deleted."
  type        = "CLOUD_FORMATION_TEMPLATE"

  provisioning_artifact_parameters {
    name         = "v-${substr(filemd5(local.template_path), 0, 8)}"
    description  = "Template from infra/cloudformation/dev-test-stack.yaml"
    template_url = "https://${aws_s3_bucket.catalog.bucket_regional_domain_name}/${aws_s3_object.template.key}"
    type         = "CLOUD_FORMATION_TEMPLATE"
  }

  # New template versions are added as provisioning artifacts, not by replacing the product.
  lifecycle {
    ignore_changes = [provisioning_artifact_parameters]
  }
}

resource "aws_servicecatalog_product_portfolio_association" "test_stack" {
  portfolio_id = aws_servicecatalog_portfolio.developers.id
  product_id   = aws_servicecatalog_product.test_stack.id
}

resource "aws_servicecatalog_principal_portfolio_association" "developers" {
  portfolio_id  = aws_servicecatalog_portfolio.developers.id
  principal_arn = data.terraform_remote_state.security.outputs.developers_group_arn
}

# ---------------------------------------------------------------------------
# Launch role: what Service Catalog uses to build the stack
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "launch_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["servicecatalog.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "launch" {
  name               = "${var.project}-catalog-launch"
  assume_role_policy = data.aws_iam_policy_document.launch_assume.json
}

data "aws_iam_policy_document" "launch" {
  statement {
    sid       = "CloudFormation"
    actions   = ["cloudformation:*"]
    resources = ["arn:aws:cloudformation:${var.primary_region}:${local.account_id}:stack/SC-*"]
  }

  statement {
    sid       = "CloudFormationRead"
    actions   = ["cloudformation:GetTemplateSummary", "cloudformation:ValidateTemplate", "cloudformation:DescribeStacks"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadTemplate"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.catalog.arn}/*"]
  }

  statement {
    sid = "BuildTheStack"
    actions = [
      "ec2:*",
      "rds:*",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "ssm:GetParameters",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.primary_region]
    }
  }

  statement {
    sid       = "RdsManagedPassword"
    actions   = ["secretsmanager:CreateSecret", "secretsmanager:TagResource", "secretsmanager:DescribeSecret", "secretsmanager:RotateSecret", "secretsmanager:PutSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.primary_region}:${local.account_id}:secret:rds!*"]
  }

  statement {
    sid       = "RdsKms"
    actions   = ["kms:DescribeKey", "kms:CreateGrant", "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["rds.${var.primary_region}.amazonaws.com", "secretsmanager.${var.primary_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "RdsServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/rds.amazonaws.com/*"]
  }
}

resource "aws_iam_role_policy" "launch" {
  name   = "provision-test-stack"
  role   = aws_iam_role.launch.id
  policy = data.aws_iam_policy_document.launch.json
}

resource "aws_servicecatalog_constraint" "launch" {
  description  = "Provision with the platform launch role"
  portfolio_id = aws_servicecatalog_portfolio.developers.id
  product_id   = aws_servicecatalog_product.test_stack.id
  type         = "LAUNCH"
  parameters   = jsonencode({ RoleArn = aws_iam_role.launch.arn })

  depends_on = [aws_servicecatalog_product_portfolio_association.test_stack]
}
