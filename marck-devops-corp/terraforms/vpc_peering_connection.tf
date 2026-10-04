resource "aws_vpc_peering_connection" "prod_dev" {
  vpc_id      = aws_vpc.production.id
  peer_vpc_id = aws_vpc.development.id
  auto_accept = true

  tags = {
    Name = "pcx-prod-dev"
  }
}

resource "aws_vpc_peering_connection_options" "prod_dev" {
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "prod_db_to_dev_db" {
  route_table_id            = aws_route_table.db.id
  destination_cidr_block    = local.dev_subnets.db.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id
}

resource "aws_route" "dev_db_to_prod_db_a" {
  route_table_id            = aws_route_table.dev_db.id
  destination_cidr_block    = local.prod_subnets.db_a.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id
}

resource "aws_route" "dev_db_to_prod_db_b" {
  route_table_id            = aws_route_table.dev_db.id
  destination_cidr_block    = local.prod_subnets.db_b.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id
}
