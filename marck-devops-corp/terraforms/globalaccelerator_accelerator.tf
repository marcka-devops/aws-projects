resource "aws_globalaccelerator_accelerator" "app" {
  provider        = aws.west
  name            = "${var.name_prefix}-app"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "https" {
  provider        = aws.west
  accelerator_arn = aws_globalaccelerator_accelerator.app.id
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_listener" "http" {
  provider        = aws.west
  accelerator_arn = aws_globalaccelerator_accelerator.app.id
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "https_primary" {
  provider              = aws.west
  listener_arn          = aws_globalaccelerator_listener.https.id
  endpoint_group_region = var.primary_region

  endpoint_configuration {
    endpoint_id = aws_lb.web.arn
    weight      = 128
  }
}

resource "aws_globalaccelerator_endpoint_group" "https_west" {
  provider              = aws.west
  listener_arn          = aws_globalaccelerator_listener.https.id
  endpoint_group_region = var.secondary_region

  endpoint_configuration {
    endpoint_id = aws_lb.web_west.arn
    weight      = 128
  }
}

resource "aws_globalaccelerator_endpoint_group" "http_primary" {
  provider              = aws.west
  listener_arn          = aws_globalaccelerator_listener.http.id
  endpoint_group_region = var.primary_region

  endpoint_configuration {
    endpoint_id = aws_lb.web.arn
    weight      = 128
  }
}

resource "aws_globalaccelerator_endpoint_group" "http_west" {
  provider              = aws.west
  listener_arn          = aws_globalaccelerator_listener.http.id
  endpoint_group_region = var.secondary_region

  endpoint_configuration {
    endpoint_id = aws_lb.web_west.arn
    weight      = 128
  }
}
