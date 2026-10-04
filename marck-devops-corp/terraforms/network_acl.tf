resource "aws_network_acl" "web" {
  vpc_id = aws_vpc.production.id
  subnet_ids = [
    aws_subnet.production["web_a"].id,
    aws_subnet.production["web_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-prod-web" }
}

resource "aws_network_acl_rule" "web_in_http" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "web_in_https" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "web_in_ssh" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.admin_cidr
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "web_in_ephemeral" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "web_out_web" {
  for_each = {
    "100" = 80
    "110" = 443
  }

  network_acl_id = aws_network_acl.web.id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = each.value
  to_port        = each.value
}

resource "aws_network_acl_rule" "web_out_ephemeral" {
  network_acl_id = aws_network_acl.web.id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl" "app1" {
  vpc_id = aws_vpc.production.id
  subnet_ids = [
    aws_subnet.production["app1_a"].id,
    aws_subnet.production["app1_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-prod-app1" }
}

resource "aws_network_acl_rule" "app1_in" {
  for_each = {
    http_a = { n = 100, cidr = local.prod_subnets.web_a.cidr, port = 8080 }
    http_b = { n = 110, cidr = local.prod_subnets.web_b.cidr, port = 8080 }
    ssh_a  = { n = 120, cidr = local.prod_subnets.web_a.cidr, port = 22 }
    ssh_b  = { n = 130, cidr = local.prod_subnets.web_b.cidr, port = 22 }
  }

  network_acl_id = aws_network_acl.app1.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "app1_in_ephemeral" {
  network_acl_id = aws_network_acl.app1.id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "app1_out_https" {
  network_acl_id = aws_network_acl.app1.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "app1_out" {
  for_each = {
    app2_a  = { n = 110, cidr = local.prod_subnets.app2_a.cidr, port = 8080 }
    app2_b  = { n = 120, cidr = local.prod_subnets.app2_b.cidr, port = 8080 }
    cache_a = { n = 130, cidr = local.prod_subnets.dbcache_a.cidr, port = 6379 }
    cache_b = { n = 140, cidr = local.prod_subnets.dbcache_b.cidr, port = 6379 }
    db_a    = { n = 150, cidr = local.prod_subnets.db_a.cidr, port = 3306 }
    db_b    = { n = 160, cidr = local.prod_subnets.db_b.cidr, port = 3306 }
  }

  network_acl_id = aws_network_acl.app1.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "app1_out_ephemeral" {
  network_acl_id = aws_network_acl.app1.id
  rule_number    = 170
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl" "app2" {
  vpc_id = aws_vpc.production.id
  subnet_ids = [
    aws_subnet.production["app2_a"].id,
    aws_subnet.production["app2_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-prod-app2" }
}

resource "aws_network_acl_rule" "app2_in" {
  for_each = {
    http_a = { n = 100, cidr = local.prod_subnets.app1_a.cidr, port = 8080 }
    http_b = { n = 110, cidr = local.prod_subnets.app1_b.cidr, port = 8080 }
    ssh_a  = { n = 120, cidr = local.prod_subnets.web_a.cidr, port = 22 }
    ssh_b  = { n = 130, cidr = local.prod_subnets.web_b.cidr, port = 22 }
  }

  network_acl_id = aws_network_acl.app2.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "app2_in_ephemeral" {
  network_acl_id = aws_network_acl.app2.id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.production.cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "app2_out" {
  for_each = {
    cache_a = { n = 100, cidr = local.prod_subnets.dbcache_a.cidr, port = 6379 }
    cache_b = { n = 110, cidr = local.prod_subnets.dbcache_b.cidr, port = 6379 }
    db_a    = { n = 120, cidr = local.prod_subnets.db_a.cidr, port = 3306 }
    db_b    = { n = 130, cidr = local.prod_subnets.db_b.cidr, port = 3306 }
  }

  network_acl_id = aws_network_acl.app2.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "app2_out_vpc" {
  for_each = {
    "140" = 443
    "150" = 0
  }

  network_acl_id = aws_network_acl.app2.id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.production.cidr_block
  from_port      = each.value == 0 ? 1024 : each.value
  to_port        = each.value == 0 ? 65535 : each.value
}

resource "aws_network_acl" "dbcache" {
  vpc_id = aws_vpc.production.id
  subnet_ids = [
    aws_subnet.production["dbcache_a"].id,
    aws_subnet.production["dbcache_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-prod-dbcache" }
}

resource "aws_network_acl_rule" "dbcache_in_redis" {
  for_each = {
    app1_a = { n = 100, cidr = local.prod_subnets.app1_a.cidr }
    app1_b = { n = 110, cidr = local.prod_subnets.app1_b.cidr }
    app2_a = { n = 120, cidr = local.prod_subnets.app2_a.cidr }
    app2_b = { n = 130, cidr = local.prod_subnets.app2_b.cidr }
  }

  network_acl_id = aws_network_acl.dbcache.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 6379
  to_port        = 6379
}

resource "aws_network_acl_rule" "dbcache_in_ephemeral" {
  network_acl_id = aws_network_acl.dbcache.id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "dbcache_out_https" {
  network_acl_id = aws_network_acl.dbcache.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "dbcache_out_ephemeral" {
  network_acl_id = aws_network_acl.dbcache.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl" "db" {
  vpc_id = aws_vpc.production.id
  subnet_ids = [
    aws_subnet.production["db_a"].id,
    aws_subnet.production["db_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-prod-db" }
}

resource "aws_network_acl_rule" "db_in" {
  for_each = {
    app1_a = { n = 100, cidr = local.prod_subnets.app1_a.cidr }
    app1_b = { n = 110, cidr = local.prod_subnets.app1_b.cidr }
    app2_a = { n = 120, cidr = local.prod_subnets.app2_a.cidr }
    app2_b = { n = 130, cidr = local.prod_subnets.app2_b.cidr }
    dev    = { n = 140, cidr = local.dev_subnets.db.cidr }
  }

  network_acl_id = aws_network_acl.db.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "db_in_ephemeral" {
  for_each = {
    app1_a = { n = 150, cidr = local.prod_subnets.app1_a.cidr }
    app1_b = { n = 160, cidr = local.prod_subnets.app1_b.cidr }
    app2_a = { n = 170, cidr = local.prod_subnets.app2_a.cidr }
    app2_b = { n = 180, cidr = local.prod_subnets.app2_b.cidr }
    dev    = { n = 190, cidr = local.dev_subnets.db.cidr }
  }

  network_acl_id = aws_network_acl.db.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "db_out" {
  for_each = {
    app1_a = { n = 100, cidr = local.prod_subnets.app1_a.cidr }
    app1_b = { n = 110, cidr = local.prod_subnets.app1_b.cidr }
    app2_a = { n = 120, cidr = local.prod_subnets.app2_a.cidr }
    app2_b = { n = 130, cidr = local.prod_subnets.app2_b.cidr }
    dev    = { n = 140, cidr = local.dev_subnets.db.cidr }
  }

  network_acl_id = aws_network_acl.db.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "db_out_mysql_dev" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 150
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.dev_subnets.db.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl" "dev_web" {
  vpc_id     = aws_vpc.development.id
  subnet_ids = [aws_subnet.development["web"].id]

  tags = { Name = "${var.name_prefix}-dev-web" }
}

resource "aws_network_acl_rule" "dev_web_in" {
  for_each = {
    "100" = { cidr = "0.0.0.0/0", port = 80 }
    "110" = { cidr = "0.0.0.0/0", port = 443 }
    "120" = { cidr = var.admin_cidr, port = 22 }
  }

  network_acl_id = aws_network_acl.dev_web.id
  rule_number    = tonumber(each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "dev_web_in_ephemeral" {
  network_acl_id = aws_network_acl.dev_web.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "dev_web_out" {
  for_each = {
    "100" = { cidr = "0.0.0.0/0", from = 80, to = 80 }
    "110" = { cidr = "0.0.0.0/0", from = 443, to = 443 }
    "120" = { cidr = local.dev_subnets.db.cidr, from = 3306, to = 3306 }
    "130" = { cidr = "0.0.0.0/0", from = 1024, to = 65535 }
  }

  network_acl_id = aws_network_acl.dev_web.id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl" "dev_db" {
  vpc_id     = aws_vpc.development.id
  subnet_ids = [aws_subnet.development["db"].id]

  tags = { Name = "${var.name_prefix}-dev-db" }
}

resource "aws_network_acl_rule" "dev_db_in_mysql" {
  for_each = {
    web    = { n = 100, cidr = local.dev_subnets.web.cidr }
    prod_a = { n = 110, cidr = local.prod_subnets.db_a.cidr }
    prod_b = { n = 120, cidr = local.prod_subnets.db_b.cidr }
  }

  network_acl_id = aws_network_acl.dev_db.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "dev_db_in_ephemeral" {
  for_each = {
    web    = { n = 130, cidr = local.dev_subnets.web.cidr }
    prod_a = { n = 140, cidr = local.prod_subnets.db_a.cidr }
    prod_b = { n = 150, cidr = local.prod_subnets.db_b.cidr }
  }

  network_acl_id = aws_network_acl.dev_db.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "dev_db_out" {
  for_each = {
    web    = { n = 100, cidr = local.dev_subnets.web.cidr, from = 1024, to = 65535 }
    prod_a = { n = 110, cidr = local.prod_subnets.db_a.cidr, from = 3306, to = 3306 }
    prod_b = { n = 120, cidr = local.prod_subnets.db_b.cidr, from = 3306, to = 3306 }
    eph_a  = { n = 130, cidr = local.prod_subnets.db_a.cidr, from = 1024, to = 65535 }
    eph_b  = { n = 140, cidr = local.prod_subnets.db_b.cidr, from = 1024, to = 65535 }
  }

  network_acl_id = aws_network_acl.dev_db.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl" "test_web" {
  vpc_id     = aws_vpc.test.id
  subnet_ids = [aws_subnet.test["web"].id]

  tags = { Name = "${var.name_prefix}-test-web" }
}

resource "aws_network_acl_rule" "test_web_in" {
  for_each = {
    "100" = 80
    "110" = 22
  }

  network_acl_id = aws_network_acl.test_web.id
  rule_number    = tonumber(each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.admin_cidr
  from_port      = each.value
  to_port        = each.value
}

resource "aws_network_acl_rule" "test_web_in_ephemeral" {
  network_acl_id = aws_network_acl.test_web.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "test_web_out" {
  for_each = {
    "100" = { cidr = "0.0.0.0/0", from = 443, to = 443 }
    "110" = { cidr = local.test_subnets.app.cidr, from = 22, to = 22 }
    "120" = { cidr = local.test_subnets.app.cidr, from = 8080, to = 8080 }
    "130" = { cidr = "0.0.0.0/0", from = 1024, to = 65535 }
  }

  network_acl_id = aws_network_acl.test_web.id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl" "test_app" {
  vpc_id     = aws_vpc.test.id
  subnet_ids = [aws_subnet.test["app"].id]

  tags = { Name = "${var.name_prefix}-test-app" }
}

resource "aws_network_acl_rule" "test_app_in" {
  for_each = {
    "100" = 8080
    "110" = 22
  }

  network_acl_id = aws_network_acl.test_app.id
  rule_number    = tonumber(each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.test_subnets.web.cidr
  from_port      = each.value
  to_port        = each.value
}

resource "aws_network_acl_rule" "test_app_in_ephemeral" {
  network_acl_id = aws_network_acl.test_app.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.test.cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "test_app_out" {
  for_each = {
    db_a = { n = 100, cidr = local.test_subnets.db_a.cidr }
    db_b = { n = 110, cidr = local.test_subnets.db_b.cidr }
  }

  network_acl_id = aws_network_acl.test_app.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "test_app_out_ephemeral" {
  network_acl_id = aws_network_acl.test_app.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.test_subnets.web.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl" "test_db" {
  vpc_id = aws_vpc.test.id
  subnet_ids = [
    aws_subnet.test["db_a"].id,
    aws_subnet.test["db_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-test-db" }
}

resource "aws_network_acl_rule" "test_db_in" {
  network_acl_id = aws_network_acl.test_db.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.test_subnets.app.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "test_db_out" {
  network_acl_id = aws_network_acl.test_db.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.test_subnets.app.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl" "oregon_web" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id
  subnet_ids = [
    aws_subnet.oregon["web_a"].id,
    aws_subnet.oregon["web_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-oregon-web" }
}

resource "aws_network_acl_rule" "oregon_web_in" {
  provider = aws.west
  for_each = {
    "100" = 80
    "110" = 443
  }

  network_acl_id = aws_network_acl.oregon_web.id
  rule_number    = tonumber(each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = each.value
  to_port        = each.value
}

resource "aws_network_acl_rule" "oregon_web_in_ephemeral" {
  provider       = aws.west
  network_acl_id = aws_network_acl.oregon_web.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "oregon_web_out" {
  provider = aws.west
  for_each = {
    "100" = { from = 80, to = 80 }
    "110" = { from = 443, to = 443 }
    "120" = { from = 1024, to = 65535 }
  }

  network_acl_id = aws_network_acl.oregon_web.id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl" "oregon_db" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id
  subnet_ids = [
    aws_subnet.oregon["db_a"].id,
    aws_subnet.oregon["db_b"].id,
  ]

  tags = { Name = "${var.name_prefix}-oregon-db" }
}

resource "aws_network_acl_rule" "oregon_db_in" {
  provider = aws.west
  for_each = {
    web_a = { n = 100, cidr = local.oregon_subnets.web_a.cidr }
    web_b = { n = 110, cidr = local.oregon_subnets.web_b.cidr }
  }

  network_acl_id = aws_network_acl.oregon_db.id
  rule_number    = each.value.n
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "oregon_db_out" {
  provider = aws.west
  for_each = {
    web_a = { n = 100, cidr = local.oregon_subnets.web_a.cidr }
    web_b = { n = 110, cidr = local.oregon_subnets.web_b.cidr }
  }

  network_acl_id = aws_network_acl.oregon_db.id
  rule_number    = each.value.n
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}
