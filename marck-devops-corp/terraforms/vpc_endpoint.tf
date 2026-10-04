resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.production.id
  service_name      = "com.amazonaws.${var.primary_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.app1_a.id,
    aws_route_table.app1_b.id,
    aws_route_table.app2.id,
    aws_route_table.dbcache_a.id,
    aws_route_table.dbcache_b.id,
  ]

  tags = {
    Name = "${var.name_prefix}-s3"
  }
}

resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name_prefix}-endpoints-"
  description = "HTTPS from the production VPC to interface endpoints"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from the production VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.production.cidr_block
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages", "logs"])

  vpc_id              = aws_vpc.production.id
  service_name        = "com.amazonaws.${var.primary_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.production["app2_a"].id,
    aws_subnet.production["app2_b"].id,
  ]
  security_group_ids = [aws_security_group.endpoints.id]

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}
