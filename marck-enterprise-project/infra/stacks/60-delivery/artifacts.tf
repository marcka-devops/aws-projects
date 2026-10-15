# Pipeline artifact stores. CodePipeline copies each build to the Oregon bucket for the
# cross-region deployment, so both regions read the bundle locally.

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "artifacts_west" {
  provider      = aws.west
  bucket        = local.artifact_bucket_west
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "artifacts_west" {
  provider                = aws.west
  bucket                  = aws_s3_bucket.artifacts_west.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "artifacts_west" {
  provider = aws.west
  bucket   = aws_s3_bucket.artifacts_west.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-builds"
    status = "Enabled"
    filter {}
    expiration {
      days = 60
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_west" {
  provider = aws.west
  bucket   = aws_s3_bucket.artifacts_west.id
  rule {
    id     = "expire-old-builds"
    status = "Enabled"
    filter {}
    expiration {
      days = 60
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
