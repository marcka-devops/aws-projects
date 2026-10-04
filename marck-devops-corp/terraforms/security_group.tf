resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Public HTTP and HTTPS for the Virginia load balancer"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_security_group" "alb_west" {
  provider    = aws.west
  name_prefix = "${var.name_prefix}-alb-"
  description = "Public HTTP and HTTPS for the Oregon load balancer"
  vpc_id      = aws_vpc.oregon.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  description = "SSH from the administrator network"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-bastion" }
}

resource "aws_security_group" "web" {
  name_prefix = "${var.name_prefix}-web-"
  description = "Web fleet in the production public subnets"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-web" }
}

resource "aws_security_group" "web_west" {
  provider    = aws.west
  name_prefix = "${var.name_prefix}-web-"
  description = "Warm web fleet in Oregon"
  vpc_id      = aws_vpc.oregon.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-web" }
}

resource "aws_security_group" "app1" {
  name_prefix = "${var.name_prefix}-app1-"
  description = "First private application tier"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-app1" }
}

resource "aws_security_group" "app2" {
  name_prefix = "${var.name_prefix}-app2-"
  description = "Second private application tier"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-app2" }
}

resource "aws_security_group" "cache" {
  name_prefix = "${var.name_prefix}-cache-"
  description = "Redis in the dbcache subnets"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-cache" }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name_prefix}-db-"
  description = "Aurora MySQL in the production database subnets"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-db" }
}

resource "aws_security_group" "db_west" {
  provider    = aws.west
  name_prefix = "${var.name_prefix}-db-"
  description = "Aurora reader in Oregon"
  vpc_id      = aws_vpc.oregon.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-db" }
}

resource "aws_security_group" "fsx" {
  name_prefix = "${var.name_prefix}-fsx-"
  description = "Lustre mount from the web fleet"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-fsx" }
}

resource "aws_security_group" "dev_web" {
  name_prefix = "${var.name_prefix}-dev-web-"
  description = "Development web subnet"
  vpc_id      = aws_vpc.development.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-dev-web" }
}

resource "aws_security_group" "dev_db" {
  name_prefix = "${var.name_prefix}-dev-db-"
  description = "Development database subnet"
  vpc_id      = aws_vpc.development.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-dev-db" }
}

resource "aws_security_group" "test_web" {
  name_prefix = "${var.name_prefix}-test-web-"
  description = "Test web subnet"
  vpc_id      = aws_vpc.test.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-test-web" }
}

resource "aws_security_group" "test_app" {
  name_prefix = "${var.name_prefix}-test-app-"
  description = "Test application subnet"
  vpc_id      = aws_vpc.test.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-test-app" }
}

resource "aws_security_group" "test_db" {
  name_prefix = "${var.name_prefix}-test-db-"
  description = "Test database subnet"
  vpc_id      = aws_vpc.test.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-test-db" }
}

resource "aws_security_group" "imagebuilder" {
  name_prefix = "${var.name_prefix}-imagebuilder-"
  description = "Build instances for the web image"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-imagebuilder" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_west_http" {
  provider          = aws.west
  security_group_id = aws_security_group.alb_west.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_west_https" {
  provider          = aws.west
  security_group_id = aws_security_group.alb_west.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_west_to_web" {
  provider                     = aws.west
  security_group_id            = aws_security_group.alb_west.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.web_west.id
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from the administrator network"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_ssh" {
  for_each = {
    web  = aws_security_group.web.id
    app1 = aws_security_group.app1.id
    app2 = aws_security_group.app2.id
  }

  security_group_id            = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "web_to_app1" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.app1.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_fsx" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 988
  to_port                      = 988
  referenced_security_group_id = aws_security_group.fsx.id
}

resource "aws_vpc_security_group_ingress_rule" "web_west_http" {
  provider                     = aws.west
  security_group_id            = aws_security_group.web_west.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb_west.id
}

resource "aws_vpc_security_group_egress_rule" "web_west_https" {
  provider          = aws.west
  security_group_id = aws_security_group.web_west.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app1_http" {
  security_group_id            = aws_security_group.app1.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "app1_ssh_web" {
  security_group_id            = aws_security_group.app1.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "app1_https" {
  security_group_id = aws_security_group.app1.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app1_to_app2" {
  security_group_id            = aws_security_group.app1.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.app2.id
}

resource "aws_vpc_security_group_egress_rule" "app1_to_cache" {
  security_group_id            = aws_security_group.app1.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.cache.id
}

resource "aws_vpc_security_group_egress_rule" "app1_to_db" {
  security_group_id            = aws_security_group.app1.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_ingress_rule" "app2_http" {
  security_group_id            = aws_security_group.app2.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.app1.id
}

resource "aws_vpc_security_group_ingress_rule" "app2_ssh" {
  security_group_id            = aws_security_group.app2.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "app2_https" {
  security_group_id = aws_security_group.app2.id
  description       = "Session Manager and interface endpoints stay inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.production.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "app2_to_cache" {
  security_group_id            = aws_security_group.app2.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.cache.id
}

resource "aws_vpc_security_group_egress_rule" "app2_to_db" {
  security_group_id            = aws_security_group.app2.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_ingress_rule" "cache" {
  for_each = {
    app1 = aws_security_group.app1.id
    app2 = aws_security_group.app2.id
  }

  security_group_id            = aws_security_group.cache.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  for_each = {
    app1   = aws_security_group.app1.id
    app2   = aws_security_group.app2.id
    dev_db = aws_security_group.dev_db.id
  }

  depends_on = [aws_vpc_peering_connection_options.prod_dev]

  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "db_west" {
  provider                     = aws.west
  security_group_id            = aws_security_group.db_west.id
  description                  = "Reader traffic from the warm web fleet"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.web_west.id
}

resource "aws_vpc_security_group_ingress_rule" "fsx" {
  security_group_id            = aws_security_group.fsx.id
  ip_protocol                  = "tcp"
  from_port                    = 988
  to_port                      = 988
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_ingress_rule" "dev_web_http" {
  security_group_id = aws_security_group.dev_web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dev_web_https" {
  security_group_id = aws_security_group.dev_web.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dev_web_ssh" {
  security_group_id = aws_security_group.dev_web.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "dev_web_https" {
  security_group_id = aws_security_group.dev_web.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dev_web_to_db" {
  security_group_id            = aws_security_group.dev_web.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.dev_db.id
}

resource "aws_vpc_security_group_ingress_rule" "dev_db" {
  for_each = {
    dev_web = aws_security_group.dev_web.id
    prod_db = aws_security_group.db.id
  }

  depends_on = [aws_vpc_peering_connection_options.prod_dev]

  security_group_id            = aws_security_group.dev_db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_egress_rule" "dev_db_to_prod" {
  depends_on                   = [aws_vpc_peering_connection_options.prod_dev]
  security_group_id            = aws_security_group.dev_db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_ingress_rule" "test_web_http" {
  security_group_id = aws_security_group.test_web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "test_web_ssh" {
  security_group_id = aws_security_group.test_web.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "test_web" {
  for_each = {
    https = 443
    app   = 8080
    ssh   = 22
  }

  security_group_id = aws_security_group.test_web.id
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  cidr_ipv4         = each.key == "https" ? "0.0.0.0/0" : aws_vpc.test.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "test_app" {
  for_each = toset(["8080", "22"])

  security_group_id            = aws_security_group.test_app.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.test_web.id
}

resource "aws_vpc_security_group_egress_rule" "test_app_db" {
  security_group_id            = aws_security_group.test_app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.test_db.id
}

resource "aws_vpc_security_group_ingress_rule" "test_db" {
  security_group_id            = aws_security_group.test_db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.test_app.id
}

resource "aws_vpc_security_group_egress_rule" "imagebuilder" {
  security_group_id = aws_security_group.imagebuilder.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}
