# ELB/ASG/Route 53 case study:
#   1. Scale out above 80% CPU, scale in below 60% (module web_fleet).
#   2. A load balancer spreads requests across the instances.
#   3. The company domain routes to the application: app.<domain> -> Global Accelerator -> ALBs.

# ---------------------------------------------------------------------------
# Certificates for app.<domain> in each region
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "app_east" {
  count             = var.enable_https ? 1 : 0
  domain_name       = local.app_host
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "app_west" {
  count             = var.enable_https ? 1 : 0
  provider          = aws.west
  domain_name       = local.app_host
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# ACM issues the same validation record for the same name in every region, so one record serves both.
resource "aws_route53_record" "app_validation" {
  count = var.enable_https ? 1 : 0

  zone_id         = local.net.zone_id
  name            = one(aws_acm_certificate.app_east[0].domain_validation_options).resource_record_name
  type            = one(aws_acm_certificate.app_east[0].domain_validation_options).resource_record_type
  records         = [one(aws_acm_certificate.app_east[0].domain_validation_options).resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app_east" {
  count                   = var.enable_https ? 1 : 0
  certificate_arn         = aws_acm_certificate.app_east[0].arn
  validation_record_fqdns = [aws_route53_record.app_validation[0].fqdn]
}

resource "aws_acm_certificate_validation" "app_west" {
  count                   = var.enable_https ? 1 : 0
  provider                = aws.west
  certificate_arn         = aws_acm_certificate.app_west[0].arn
  validation_record_fqdns = [aws_route53_record.app_validation[0].fqdn]
}

# ---------------------------------------------------------------------------
# Production fleet (Virginia): ALB in web subnets, instances in app1 subnets
# ---------------------------------------------------------------------------
module "fleet_east" {
  source = "../../modules/web_fleet"

  name                        = "${var.project}-web-east"
  vpc_id                      = local.net.prod.vpc_id
  alb_subnet_ids              = local.net.prod.subnet_ids["web"]
  instance_subnet_ids         = local.net.prod.subnet_ids["app1"]
  alb_security_group_id       = local.net.prod.sg.alb
  instance_security_group_ids = [local.net.prod.sg.app]

  ami_id                = local.ami_east
  instance_type         = var.instance_type
  instance_profile_name = aws_iam_instance_profile.instance.name
  user_data = templatefile("${path.module}/templates/web-user-data.sh.tftpl", {
    region  = var.primary_region
    role    = "production"
    fsx_dns = var.enable_fsx ? aws_fsx_openzfs_file_system.shared[0].dns_name : ""
  })

  min_size         = var.fleet_min
  max_size         = var.fleet_max
  desired_capacity = var.fleet_min
  certificate_arn  = var.enable_https ? aws_acm_certificate_validation.app_east[0].certificate_arn : null
  alarm_actions    = [local.alerts]

  tags = { Role = "web", DeployGroup = "production" }
}

# ---------------------------------------------------------------------------
# Warm standby fleet (Oregon)
# ---------------------------------------------------------------------------
module "fleet_west" {
  source    = "../../modules/web_fleet"
  providers = { aws = aws.west }

  name                        = "${var.project}-web-west"
  vpc_id                      = local.net.west.vpc_id
  alb_subnet_ids              = local.net.west.subnet_ids["web"]
  instance_subnet_ids         = local.net.west.subnet_ids["app"]
  alb_security_group_id       = local.net.west.sg.alb
  instance_security_group_ids = [local.net.west.sg.app]

  ami_id                = local.ami_west
  instance_type         = var.instance_type
  instance_profile_name = aws_iam_instance_profile.instance.name
  user_data = templatefile("${path.module}/templates/web-user-data.sh.tftpl", {
    region  = var.secondary_region
    role    = "standby"
    fsx_dns = ""
  })

  min_size         = var.west_fleet_min
  max_size         = var.fleet_max
  desired_capacity = var.west_fleet_min
  certificate_arn  = var.enable_https ? aws_acm_certificate_validation.app_west[0].certificate_arn : null

  tags = { Role = "web", DeployGroup = "standby" }
}

# ---------------------------------------------------------------------------
# Global Accelerator: two static anycast IPs in front of both regions
# ---------------------------------------------------------------------------
resource "aws_globalaccelerator_accelerator" "app" {
  name            = "${var.project}-app"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "app" {
  accelerator_arn = aws_globalaccelerator_accelerator.app.id
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "east" {
  listener_arn            = aws_globalaccelerator_listener.app.id
  endpoint_group_region   = var.primary_region
  traffic_dial_percentage = 100

  endpoint_configuration {
    endpoint_id                    = module.fleet_east.alb_arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

resource "aws_globalaccelerator_endpoint_group" "west" {
  listener_arn            = aws_globalaccelerator_listener.app.id
  endpoint_group_region   = var.secondary_region
  traffic_dial_percentage = 100

  endpoint_configuration {
    endpoint_id                    = module.fleet_west.alb_arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = local.net.zone_id
  name    = local.app_host
  type    = "A"

  alias {
    name                   = aws_globalaccelerator_accelerator.app.dns_name
    zone_id                = aws_globalaccelerator_accelerator.app.hosted_zone_id
    evaluate_target_health = true
  }
}
