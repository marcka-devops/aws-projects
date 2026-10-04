resource "aws_cloudtrail" "management" {
  name                          = "${var.name_prefix}-management"
  s3_bucket_name                = aws_s3_bucket.platform["cloudtrail"].id
  kms_key_id                    = aws_kms_key.primary.arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
