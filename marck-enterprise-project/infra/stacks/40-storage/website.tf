# S3 Versioning case study, tasks 4-5.
#   4. Host the static website on the company domain: private S3 bucket behind CloudFront.
#   5. Show an error page when the wrong host name is used: a CloudFront Function sends any
#      request that is not for www.<domain> (the bare domain, the *.cloudfront.net name) to error.html.

resource "aws_s3_bucket" "website" {
  bucket = "${var.project}-www-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  site_dir = "${path.module}/../../../website"
  content_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css"
    js   = "application/javascript"
    svg  = "image/svg+xml"
    png  = "image/png"
    ico  = "image/x-icon"
    txt  = "text/plain"
  }
}

# HTML pages are templates so they can print the real domain name.
resource "aws_s3_object" "site" {
  for_each = fileset(local.site_dir, "**")

  bucket       = aws_s3_bucket.website.id
  key          = each.value
  content_type = lookup(local.content_types, reverse(split(".", each.value))[0], "application/octet-stream")

  content = endswith(each.value, ".html") ? templatefile("${local.site_dir}/${each.value}", {
    domain = local.domain
    www    = local.www
  }) : null
  source = endswith(each.value, ".html") ? null : "${local.site_dir}/${each.value}"

  etag = endswith(each.value, ".html") ? null : filemd5("${local.site_dir}/${each.value}")
}

# ---------------------------------------------------------------------------
# Certificate (us-east-1) and CloudFront
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name               = local.www
  subject_alternative_names = [local.domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_validation" {
  for_each = {
    for o in aws_acm_certificate.site.domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      type   = o.resource_record_type
      record = o.resource_record_value
    }
  }

  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.site_validation : r.fqdn]
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project}-www"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "host_check" {
  name    = "${var.project}-host-check"
  runtime = "cloudfront-js-2.0"
  comment = "Serve error.html unless the request is for ${local.www}"
  publish = true
  code    = templatefile("${path.module}/host-check.js.tftpl", { www = local.www })
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Marck Enterprise website"
  default_root_object = "index.html"
  aliases             = [local.www, local.domain]
  price_class         = "PriceClass_100"

  origin {
    origin_id                = "s3-website"
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-website"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_check.arn
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/error.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "CloudFrontReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.website.arn, "${aws_s3_bucket.website.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

resource "aws_route53_record" "website" {
  for_each = {
    for pair in setproduct([local.www, local.domain], ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => {
      name = pair[0]
      type = pair[1]
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
