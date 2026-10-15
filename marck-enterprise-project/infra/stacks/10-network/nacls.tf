# Network ACLs are the stateless second layer behind security groups.
# Return traffic needs explicit ephemeral-port rules (1024-65535) because NACLs keep no state.

locals {
  prod_cidr = module.prod_vpc.cidr
  dev_cidr  = module.dev_vpc.cidr
  anywhere  = "0.0.0.0/0"
  eph_from  = 1024
  eph_to    = 65535

  # One rule per prod db CIDR for the development side.
  dev_db_from_prod = flatten([
    for i, cidr in local.prod_db_cidrs : [
      { rule_no = 110 + i, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = cidr },
      { rule_no = 120 + i, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = cidr },
    ]
  ])
  dev_db_to_prod = flatten([
    for i, cidr in local.prod_db_cidrs : [
      { rule_no = 110 + i, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = cidr },
      { rule_no = 120 + i, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = cidr },
    ]
  ])
}

# ----------------------------- production ---------------------------------
module "nacl_prod_web" {
  source     = "../../modules/nacl"
  name       = "${var.project}-prod-web"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["web"]

  ingress = [
    { rule_no = 100, protocol = "tcp", from_port = 80, to_port = 80, cidr = local.anywhere },
    { rule_no = 110, protocol = "tcp", from_port = 443, to_port = 443, cidr = local.anywhere },
    { rule_no = 120, protocol = "tcp", from_port = 22, to_port = 22, cidr = var.admin_cidr },
    { rule_no = 130, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.anywhere },
    # The NAT gateways live here and forward traffic from the private tiers.
    { rule_no = 140, protocol = "-1", cidr = local.prod_cidr },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = local.anywhere },
  ]
}

module "nacl_prod_app1" {
  source     = "../../modules/nacl"
  name       = "${var.project}-prod-app1"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["app1"]

  ingress = [
    { rule_no = 100, protocol = "-1", cidr = local.prod_cidr },
    { rule_no = 110, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.anywhere },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = local.anywhere },
  ]
}

module "nacl_prod_app2" {
  source     = "../../modules/nacl"
  name       = "${var.project}-prod-app2"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["app2"]

  ingress = [
    { rule_no = 100, protocol = "-1", cidr = local.prod_cidr },
    # S3 responses arrive through the gateway endpoint from public S3 addresses.
    { rule_no = 110, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.anywhere },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = local.prod_cidr },
    { rule_no = 110, protocol = "tcp", from_port = 443, to_port = 443, cidr = local.anywhere },
  ]
}

module "nacl_prod_dbcache" {
  source     = "../../modules/nacl"
  name       = "${var.project}-prod-dbcache"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["dbcache"]

  ingress = [
    { rule_no = 100, protocol = "tcp", from_port = 6379, to_port = 6379, cidr = local.prod_cidr },
    { rule_no = 110, protocol = "tcp", from_port = 22, to_port = 22, cidr = local.prod_cidr },
    { rule_no = 120, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.anywhere },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = local.anywhere },
  ]
}

module "nacl_prod_db" {
  source     = "../../modules/nacl"
  name       = "${var.project}-prod-db"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["db"]

  ingress = concat(
    [
      { rule_no = 100, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = local.prod_cidr },
      { rule_no = 105, protocol = "tcp", from_port = 22, to_port = 22, cidr = local.prod_cidr },
      { rule_no = 108, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.prod_cidr },
    ],
    [for i, cidr in local.dev_db_cidrs : { rule_no = 110 + i, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = cidr }],
    [for i, cidr in local.dev_db_cidrs : { rule_no = 120 + i, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = cidr }],
  )
  egress = concat(
    [{ rule_no = 100, protocol = "-1", cidr = local.prod_cidr }],
    [for i, cidr in local.dev_db_cidrs : { rule_no = 110 + i, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = cidr }],
    [for i, cidr in local.dev_db_cidrs : { rule_no = 120 + i, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = cidr }],
  )
}

# ----------------------------- development --------------------------------
module "nacl_dev_web" {
  source     = "../../modules/nacl"
  name       = "${var.project}-dev-web"
  vpc_id     = module.dev_vpc.vpc_id
  subnet_ids = module.dev_vpc.subnet_ids["web"]

  ingress = [
    { rule_no = 100, protocol = "tcp", from_port = 80, to_port = 80, cidr = local.anywhere },
    { rule_no = 110, protocol = "tcp", from_port = 443, to_port = 443, cidr = local.anywhere },
    { rule_no = 120, protocol = "tcp", from_port = 22, to_port = 22, cidr = var.admin_cidr },
    { rule_no = 130, protocol = "tcp", from_port = local.eph_from, to_port = local.eph_to, cidr = local.anywhere },
    { rule_no = 140, protocol = "-1", cidr = local.dev_cidr },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = local.anywhere },
  ]
}

module "nacl_dev_db" {
  source     = "../../modules/nacl"
  name       = "${var.project}-dev-db"
  vpc_id     = module.dev_vpc.vpc_id
  subnet_ids = module.dev_vpc.subnet_ids["db"]

  ingress = concat([{ rule_no = 100, protocol = "-1", cidr = local.dev_cidr }], local.dev_db_from_prod)
  egress  = concat([{ rule_no = 100, protocol = "-1", cidr = local.dev_cidr }], local.dev_db_to_prod)
}
