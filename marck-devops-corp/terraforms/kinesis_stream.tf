resource "aws_kinesis_stream" "telemetry" {
  name             = "${var.name_prefix}-telemetry"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.primary.arn
}
