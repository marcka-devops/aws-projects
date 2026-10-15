# ---------------------------------------------------------------------------
# VPC endpoints: S3 without the internet, Session Manager for tiers with no NAT
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint" "prod_s3" {
  vpc_id            = module.prod_vpc.vpc_id
  service_name      = "com.amazonaws.${var.primary_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.prod_vpc.route_table_ids["app1"],
    module.prod_vpc.route_table_ids["app2"],
    module.prod_vpc.route_table_ids["dbcache"],
    module.prod_vpc.route_table_ids["db"],
  )
  tags = { Name = "${var.project}-prod-s3" }
}

resource "aws_vpc_endpoint" "prod_ssm" {
  for_each = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])

  vpc_id              = module.prod_vpc.vpc_id
  service_name        = "com.amazonaws.${var.primary_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.prod_vpc.subnet_ids["app2"]
  security_group_ids  = [aws_security_group.prod_endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project}-prod-${each.value}" }
}

resource "aws_vpc_endpoint" "west_s3" {
  provider          = aws.west
  vpc_id            = module.west_vpc.vpc_id
  service_name      = "com.amazonaws.${var.secondary_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.west_vpc.route_table_ids["app"], module.west_vpc.route_table_ids["db"])
  tags              = { Name = "${var.project}-west-s3" }
}

# ---------------------------------------------------------------------------
# Public DNS for the company domain
# ---------------------------------------------------------------------------
resource "aws_route53_zone" "main" {
  count   = var.create_hosted_zone ? 1 : 0
  name    = var.domain_name
  comment = "Marck Enterprise public zone"
}

data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id      = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  name_servers = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : data.aws_route53_zone.main[0].name_servers
}
