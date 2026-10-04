resource "aws_route_table" "web" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-web"
  }
}

resource "aws_route_table" "app1_a" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-app1-a"
  }
}

resource "aws_route_table" "app1_b" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-app1-b"
  }
}

resource "aws_route_table" "app2" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-app2"
  }
}

resource "aws_route_table" "dbcache_a" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-dbcache-a"
  }
}

resource "aws_route_table" "dbcache_b" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-dbcache-b"
  }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-prod-db"
  }
}

resource "aws_route_table" "dev_web" {
  vpc_id = aws_vpc.development.id

  tags = {
    Name = "${var.name_prefix}-dev-web"
  }
}

resource "aws_route_table" "dev_db" {
  vpc_id = aws_vpc.development.id

  tags = {
    Name = "${var.name_prefix}-dev-db"
  }
}

resource "aws_route_table" "test_web" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name = "${var.name_prefix}-test-web"
  }
}

resource "aws_route_table" "test_app" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name = "${var.name_prefix}-test-app"
  }
}

resource "aws_route_table" "test_db" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name = "${var.name_prefix}-test-db"
  }
}

resource "aws_route_table" "oregon_web" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id

  tags = {
    Name = "${var.name_prefix}-oregon-web"
  }
}

resource "aws_route_table" "oregon_db" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id

  tags = {
    Name = "${var.name_prefix}-oregon-db"
  }
}

resource "aws_route" "web_default" {
  route_table_id         = aws_route_table.web.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.production.id
}

resource "aws_route" "app1_a_default" {
  route_table_id         = aws_route_table.app1_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.production["a"].id
}

resource "aws_route" "app1_b_default" {
  route_table_id         = aws_route_table.app1_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.production["b"].id
}

resource "aws_route" "dbcache_a_default" {
  route_table_id         = aws_route_table.dbcache_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.production["a"].id
}

resource "aws_route" "dbcache_b_default" {
  route_table_id         = aws_route_table.dbcache_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.production["b"].id
}

resource "aws_route" "dev_web_default" {
  route_table_id         = aws_route_table.dev_web.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.development.id
}

resource "aws_route" "test_web_default" {
  route_table_id         = aws_route_table.test_web.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test.id
}

resource "aws_route" "oregon_web_default" {
  provider               = aws.west
  route_table_id         = aws_route_table.oregon_web.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.oregon.id
}

resource "aws_route_table_association" "production" {
  for_each = {
    web_a     = { subnet = aws_subnet.production["web_a"].id, table = aws_route_table.web.id }
    web_b     = { subnet = aws_subnet.production["web_b"].id, table = aws_route_table.web.id }
    app1_a    = { subnet = aws_subnet.production["app1_a"].id, table = aws_route_table.app1_a.id }
    app1_b    = { subnet = aws_subnet.production["app1_b"].id, table = aws_route_table.app1_b.id }
    app2_a    = { subnet = aws_subnet.production["app2_a"].id, table = aws_route_table.app2.id }
    app2_b    = { subnet = aws_subnet.production["app2_b"].id, table = aws_route_table.app2.id }
    dbcache_a = { subnet = aws_subnet.production["dbcache_a"].id, table = aws_route_table.dbcache_a.id }
    dbcache_b = { subnet = aws_subnet.production["dbcache_b"].id, table = aws_route_table.dbcache_b.id }
    db_a      = { subnet = aws_subnet.production["db_a"].id, table = aws_route_table.db.id }
    db_b      = { subnet = aws_subnet.production["db_b"].id, table = aws_route_table.db.id }
  }

  subnet_id      = each.value.subnet
  route_table_id = each.value.table
}

resource "aws_route_table_association" "development" {
  for_each = {
    web = { subnet = aws_subnet.development["web"].id, table = aws_route_table.dev_web.id }
    db  = { subnet = aws_subnet.development["db"].id, table = aws_route_table.dev_db.id }
  }

  subnet_id      = each.value.subnet
  route_table_id = each.value.table
}

resource "aws_route_table_association" "test" {
  for_each = {
    web  = { subnet = aws_subnet.test["web"].id, table = aws_route_table.test_web.id }
    app  = { subnet = aws_subnet.test["app"].id, table = aws_route_table.test_app.id }
    db_a = { subnet = aws_subnet.test["db_a"].id, table = aws_route_table.test_db.id }
    db_b = { subnet = aws_subnet.test["db_b"].id, table = aws_route_table.test_db.id }
  }

  subnet_id      = each.value.subnet
  route_table_id = each.value.table
}

resource "aws_route_table_association" "oregon" {
  provider = aws.west
  for_each = {
    web_a = { subnet = aws_subnet.oregon["web_a"].id, table = aws_route_table.oregon_web.id }
    web_b = { subnet = aws_subnet.oregon["web_b"].id, table = aws_route_table.oregon_web.id }
    db_a  = { subnet = aws_subnet.oregon["db_a"].id, table = aws_route_table.oregon_db.id }
    db_b  = { subnet = aws_subnet.oregon["db_b"].id, table = aws_route_table.oregon_db.id }
  }

  subnet_id      = each.value.subnet
  route_table_id = each.value.table
}
