# Automation and Configuration Management case study, task 4.
# The brief asks for an OpsWorks stack. AWS retired OpsWorks Stacks on 26 May 2024, so the same
# job (configure servers from code, keep them in that state) is done with Ansible playbooks
# applied by Systems Manager State Manager. The playbooks live in config/ansible.

resource "aws_s3_bucket" "config" {
  bucket = "${var.project}-config-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

locals {
  ansible_dir = "${path.module}/../../../config/ansible"
}

resource "aws_s3_object" "ansible" {
  for_each = fileset(local.ansible_dir, "**")

  bucket = aws_s3_bucket.config.id
  key    = "ansible/${each.value}"
  source = "${local.ansible_dir}/${each.value}"
  etag   = filemd5("${local.ansible_dir}/${each.value}")
}

resource "aws_ssm_document" "apply_playbook" {
  name            = "${var.project}-ApplyPlaybook"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Download the Marck Enterprise Ansible playbooks from S3 and apply one locally."
    parameters = {
      Playbook = {
        type           = "String"
        description    = "Playbook file in config/ansible, for example baseline.yml"
        allowedPattern = "^[a-z0-9_-]+\\.yml$"
      }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "applyPlaybook"
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "set -euo pipefail",
          "if ! command -v ansible-playbook >/dev/null 2>&1; then dnf install -y python3-pip && python3 -m pip install --quiet 'ansible-core>=2.16,<2.19'; fi",
          "export PATH=$PATH:/usr/local/bin",
          "mkdir -p /opt/marck/ansible",
          "aws s3 sync s3://${aws_s3_bucket.config.id}/ansible/ /opt/marck/ansible/ --delete --region ${var.primary_region}",
          "cd /opt/marck/ansible",
          "ansible-playbook -i localhost, -c local '{{ Playbook }}'",
        ]
      }
    }]
  })
}

# Baseline for every instance tagged ConfigManaged=true, re-applied daily to correct drift.
resource "aws_ssm_association" "baseline" {
  name                = aws_ssm_document.apply_playbook.name
  association_name    = "${var.project}-baseline"
  schedule_expression = "rate(1 day)"
  parameters          = { Playbook = "baseline.yml" }

  targets {
    key    = "tag:ConfigManaged"
    values = ["true"]
  }

  depends_on = [aws_s3_object.ansible]
}

# Hello World web page, the OpsWorks replacement.
resource "aws_ssm_association" "hello_world" {
  name                = aws_ssm_document.apply_playbook.name
  association_name    = "${var.project}-hello-world"
  schedule_expression = "rate(1 day)"
  parameters          = { Playbook = "hello-world.yml" }

  targets {
    key    = "tag:Role"
    values = ["hello-world"]
  }

  depends_on = [aws_s3_object.ansible]
}
