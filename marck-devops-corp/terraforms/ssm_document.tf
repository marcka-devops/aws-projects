resource "aws_ssm_document" "configure" {
  name          = "${var.name_prefix}-configure"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Record that the instance was configured by State Manager."
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configure"
        inputs = {
          runCommand = ["echo configured"]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "configure" {
  name                = aws_ssm_document.configure.name
  association_name    = "${var.name_prefix}-configure"
  schedule_expression = "rate(1 day)"

  targets {
    key    = "tag:Name"
    values = ["${var.name_prefix}-web", "${var.name_prefix}-dev-web"]
  }
}
