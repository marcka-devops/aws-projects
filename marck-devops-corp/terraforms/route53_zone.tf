resource "aws_acm_certificate" "east" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
}

resource "aws_acm_certificate" "west" {
  provider          = aws.west
  domain_name       = "app.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_east" {
  for_each = {
    for dvo in aws_acm_certificate.east.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.public.zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

resource "aws_route53_record" "cert_west" {
  for_each = {
    for dvo in aws_acm_certificate.west.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.public.zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

resource "aws_acm_certificate_validation" "east" {
  certificate_arn         = aws_acm_certificate.east.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_east : record.fqdn]
}

resource "aws_acm_certificate_validation" "west" {
  provider                = aws.west
  certificate_arn         = aws_acm_certificate.west.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_west : record.fqdn]
}

resource "aws_route53_zone" "public" {
  name = var.domain_name
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_globalaccelerator_accelerator.app.dns_name
    zone_id                = aws_globalaccelerator_accelerator.app.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www.domain_name
    zone_id                = aws_cloudfront_distribution.www.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "test" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "test.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [aws_cloudformation_stack.test.outputs["WebPublicIp"]]
}

resource "aws_route53_health_check" "primary_alb" {
  fqdn              = aws_lb.web.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.name_prefix}-primary-alb"
  }
}
