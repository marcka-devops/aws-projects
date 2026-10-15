# Production <-> development peering. Routes exist only between the two db tiers,
# so nothing else in either VPC can use the connection.

resource "aws_vpc_peering_connection" "prod_dev" {
  vpc_id      = module.prod_vpc.vpc_id
  peer_vpc_id = module.dev_vpc.vpc_id
  auto_accept = true

  tags = { Name = "${var.project}-prod-dev-db" }
}

locals {
  prod_db_cidrs = module.prod_vpc.subnet_cidrs["db"]
  dev_db_cidrs  = module.dev_vpc.subnet_cidrs["db"]

  prod_db_routes = {
    for pair in setproduct(range(length(local.prod_db_cidrs)), local.dev_db_cidrs) :
    "${pair[0]}-${pair[1]}" => { rt = module.prod_vpc.route_table_ids["db"][pair[0]], cidr = pair[1] }
  }

  dev_db_routes = {
    for pair in setproduct(range(length(local.dev_db_cidrs)), local.prod_db_cidrs) :
    "${pair[0]}-${pair[1]}" => { rt = module.dev_vpc.route_table_ids["db"][pair[0]], cidr = pair[1] }
  }
}

resource "aws_route" "prod_db_to_dev_db" {
  for_each = local.prod_db_routes

  route_table_id            = each.value.rt
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id
}

resource "aws_route" "dev_db_to_prod_db" {
  for_each = local.dev_db_routes

  route_table_id            = each.value.rt
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_dev.id
}
