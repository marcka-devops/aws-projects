resource "aws_cloudfront_origin_access_control" "www" {
  name                              = "${var.name_prefix}-www"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "www_host" {
  name    = "${var.name_prefix}-www-host"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var host = event.request.headers.host.value;
      if (host !== "www.${var.domain_name}") {
        return {
          statusCode: 403,
          statusDescription: "Forbidden",
          headers: { "content-type": { value: "text/html" } },
          body: { encoding: "text", data: "<h1>This site is only available at www.${var.domain_name}</h1>" }
        };
      }
      return event.request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "www" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["www.${var.domain_name}"]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.platform["www"].bucket_regional_domain_name
    origin_id                = "www"
    origin_access_control_id = aws_cloudfront_origin_access_control.www.id
  }

  default_cache_behavior {
    target_origin_id       = "www"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.www_host.arn
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 403
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
    acm_certificate_arn      = aws_acm_certificate_validation.east.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
