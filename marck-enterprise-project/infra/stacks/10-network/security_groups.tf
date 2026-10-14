# Security groups live with the network so that later stacks can reference them
# without depending on each other (data needs "app", compute needs "db", and so on).

# ============================== production ================================

resource "aws_security_group" "prod_alb" {
  name        = "${var.project}-prod-alb"
  description = "Internet-facing load balancer"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-alb" }
}

resource "aws_security_group" "prod_app" {
  name        = "${var.project}-prod-app"
  description = "Web fleet behind the load balancer"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-app" }
}

resource "aws_security_group" "prod_web_tier" {
  name        = "${var.project}-prod-web-tier"
  description = "Web tier instance: SSH from the admin network, HTTP from anywhere"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-web-tier" }
}

resource "aws_security_group" "prod_tier" {
  name        = "${var.project}-prod-tier"
  description = "Private tier instances: SSH only from the web tier"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-tier" }
}

resource "aws_security_group" "prod_db" {
  name        = "${var.project}-prod-db"
  description = "Aurora MySQL"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-db" }
}

resource "aws_security_group" "prod_cache" {
  name        = "${var.project}-prod-cache"
  description = "ElastiCache"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-cache" }
}

resource "aws_security_group" "prod_endpoints" {
  name        = "${var.project}-prod-endpoints"
  description = "Interface VPC endpoints"
  vpc_id      = module.prod_vpc.vpc_id
  tags        = { Name = "${var.project}-prod-endpoints" }
}

# alb
resource "aws_vpc_security_group_ingress_rule" "prod_alb_http" {
  security_group_id = aws_security_group.prod_alb.id
  description       = "HTTP from the internet (redirects to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "prod_alb_https" {
  security_group_id = aws_security_group.prod_alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "prod_alb_to_app" {
  security_group_id            = aws_security_group.prod_alb.id
  description                  = "To the web fleet"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.prod_app.id
}

# app
resource "aws_vpc_security_group_ingress_rule" "prod_app_from_alb" {
  security_group_id            = aws_security_group.prod_app.id
  description                  = "HTTP from the load balancer"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.prod_alb.id
}

resource "aws_vpc_security_group_egress_rule" "prod_app_all" {
  security_group_id = aws_security_group.prod_app.id
  description       = "Packages, AWS APIs, database, cache and file system"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# web tier
resource "aws_vpc_security_group_ingress_rule" "prod_web_tier_ssh" {
  security_group_id = aws_security_group.prod_web_tier.id
  description       = "SSH from the admin network"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "prod_web_tier_http" {
  security_group_id = aws_security_group.prod_web_tier.id
  description       = "HTTP for the configuration-managed Hello World page"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "prod_web_tier_all" {
  security_group_id = aws_security_group.prod_web_tier.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# private tiers
resource "aws_vpc_security_group_ingress_rule" "prod_tier_ssh" {
  security_group_id            = aws_security_group.prod_tier.id
  description                  = "SSH from the web tier only"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.prod_web_tier.id
}

resource "aws_vpc_security_group_egress_rule" "prod_tier_all" {
  security_group_id = aws_security_group.prod_tier.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# database
resource "aws_vpc_security_group_ingress_rule" "prod_db_from_app" {
  security_group_id            = aws_security_group.prod_db.id
  description                  = "MySQL from the web fleet"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.prod_app.id
}

resource "aws_vpc_security_group_ingress_rule" "prod_db_from_dev_db" {
  for_each = toset(local.dev_db_cidrs)

  security_group_id = aws_security_group.prod_db.id
  description       = "MySQL from the development db subnet over peering"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "prod_db_vpc" {
  security_group_id = aws_security_group.prod_db.id
  ip_protocol       = "-1"
  cidr_ipv4         = module.prod_vpc.cidr
}

# cache
resource "aws_vpc_security_group_ingress_rule" "prod_cache_from_app" {
  security_group_id            = aws_security_group.prod_cache.id
  description                  = "Valkey/Redis from the web fleet"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.prod_app.id
}

resource "aws_vpc_security_group_egress_rule" "prod_cache_vpc" {
  security_group_id = aws_security_group.prod_cache.id
  ip_protocol       = "-1"
  cidr_ipv4         = module.prod_vpc.cidr
}

# endpoints
resource "aws_vpc_security_group_ingress_rule" "prod_endpoints_https" {
  security_group_id = aws_security_group.prod_endpoints.id
  description       = "HTTPS from inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = module.prod_vpc.cidr
}

# ============================== development ===============================

resource "aws_security_group" "dev_web" {
  name        = "${var.project}-dev-web"
  description = "Development web (QA target)"
  vpc_id      = module.dev_vpc.vpc_id
  tags        = { Name = "${var.project}-dev-web" }
}

resource "aws_security_group" "dev_db" {
  name        = "${var.project}-dev-db"
  description = "Development db instance"
  vpc_id      = module.dev_vpc.vpc_id
  tags        = { Name = "${var.project}-dev-db" }
}

resource "aws_vpc_security_group_ingress_rule" "dev_web_http" {
  security_group_id = aws_security_group.dev_web.id
  description       = "HTTP for QA testing"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dev_web_ssh" {
  security_group_id = aws_security_group.dev_web.id
  description       = "SSH from the admin network"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "dev_web_all" {
  security_group_id = aws_security_group.dev_web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dev_db_from_web" {
  for_each = toset(["22", "3306"])

  security_group_id            = aws_security_group.dev_db.id
  description                  = "Port ${each.value} from the development web tier"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.dev_web.id
}

resource "aws_vpc_security_group_ingress_rule" "dev_db_from_prod_db" {
  for_each = toset(local.prod_db_cidrs)

  security_group_id = aws_security_group.dev_db.id
  description       = "MySQL from the production db subnets over peering"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "dev_db_vpc" {
  security_group_id = aws_security_group.dev_db.id
  ip_protocol       = "-1"
  cidr_ipv4         = module.dev_vpc.cidr
}

resource "aws_vpc_security_group_egress_rule" "dev_db_to_prod_db" {
  for_each = toset(local.prod_db_cidrs)

  security_group_id = aws_security_group.dev_db.id
  description       = "MySQL to the production db subnets over peering"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = each.value
}

# ================================ oregon ==================================

resource "aws_security_group" "west_alb" {
  provider    = aws.west
  name        = "${var.project}-west-alb"
  description = "Internet-facing load balancer"
  vpc_id      = module.west_vpc.vpc_id
  tags        = { Name = "${var.project}-west-alb" }
}

resource "aws_security_group" "west_app" {
  provider    = aws.west
  name        = "${var.project}-west-app"
  description = "Warm web fleet"
  vpc_id      = module.west_vpc.vpc_id
  tags        = { Name = "${var.project}-west-app" }
}

resource "aws_security_group" "west_db" {
  provider    = aws.west
  name        = "${var.project}-west-db"
  description = "Aurora secondary"
  vpc_id      = module.west_vpc.vpc_id
  tags        = { Name = "${var.project}-west-db" }
}

resource "aws_vpc_security_group_ingress_rule" "west_alb_web" {
  provider = aws.west
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.west_alb.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "west_alb_to_app" {
  provider                     = aws.west
  security_group_id            = aws_security_group.west_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.west_app.id
}

resource "aws_vpc_security_group_ingress_rule" "west_app_from_alb" {
  provider                     = aws.west
  security_group_id            = aws_security_group.west_app.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.west_alb.id
}

resource "aws_vpc_security_group_egress_rule" "west_app_all" {
  provider          = aws.west
  security_group_id = aws_security_group.west_app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "west_db_from_app" {
  provider                     = aws.west
  security_group_id            = aws_security_group.west_db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.west_app.id
}

resource "aws_vpc_security_group_egress_rule" "west_db_vpc" {
  provider          = aws.west
  security_group_id = aws_security_group.west_db.id
  ip_protocol       = "-1"
  cidr_ipv4         = module.west_vpc.cidr
}
