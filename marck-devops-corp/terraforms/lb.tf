resource "aws_lb" "web" {
  name               = "${var.name_prefix}-web"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.production["web_a"].id, aws_subnet.production["web_b"].id]
}

resource "aws_lb" "web_west" {
  provider           = aws.west
  name               = "${var.name_prefix}-web"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_west.id]
  subnets            = [aws_subnet.oregon["web_a"].id, aws_subnet.oregon["web_b"].id]
}

resource "aws_lb_target_group" "web" {
  name     = "${var.name_prefix}-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.production.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "web_west" {
  provider = aws.west
  name     = "${var.name_prefix}-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.oregon.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "web_https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.east.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "web_west_https" {
  provider          = aws.west
  load_balancer_arn = aws_lb.web_west.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.west.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_west.arn
  }
}

resource "aws_lb_listener" "web_west_http" {
  provider          = aws.west
  load_balancer_arn = aws_lb.web_west.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
