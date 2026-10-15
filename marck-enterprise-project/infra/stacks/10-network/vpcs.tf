data "aws_availability_zones" "east" {
  state = "available"
}

data "aws_availability_zones" "west" {
  provider = aws.west
  state    = "available"
}

locals {
  east_azs = slice(data.aws_availability_zones.east.names, 0, 2)
  west_azs = slice(data.aws_availability_zones.west.names, 0, 2)
}

# Production: 4-tier, 5 subnet roles, each mirrored across two AZs.
# web is public. app1 and dbcache reach the internet through NAT. app2 and db have no internet route.
module "prod_vpc" {
  source = "../../modules/vpc"

  name     = "${var.project}-prod"
  cidr     = "10.0.0.0/16"
  azs      = local.east_azs
  nat_mode = var.nat_mode

  tiers = {
    web     = { type = "public", cidrs = ["10.0.0.0/24", "10.0.1.0/24"] }
    app1    = { type = "nat", cidrs = ["10.0.10.0/24", "10.0.11.0/24"] }
    app2    = { type = "isolated", cidrs = ["10.0.20.0/24", "10.0.21.0/24"] }
    dbcache = { type = "nat", cidrs = ["10.0.30.0/24", "10.0.31.0/24"] }
    db      = { type = "isolated", cidrs = ["10.0.40.0/24", "10.0.41.0/24"] }
  }

  enable_flow_logs = var.enable_flow_logs
  tags             = { Network = "production" }
}

# Development: 2-tier. Only web can send internet requests.
module "dev_vpc" {
  source = "../../modules/vpc"

  name     = "${var.project}-dev"
  cidr     = "10.1.0.0/16"
  azs      = local.east_azs
  nat_mode = "none"

  tiers = {
    web = { type = "public", cidrs = ["10.1.0.0/24"] }
    db  = { type = "isolated", cidrs = ["10.1.10.0/24"] }
  }

  enable_flow_logs = var.enable_flow_logs
  tags             = { Network = "development" }
}

# Oregon: warm standby web fleet and the Aurora secondary.
module "west_vpc" {
  source    = "../../modules/vpc"
  providers = { aws = aws.west }

  name     = "${var.project}-west"
  cidr     = "10.2.0.0/16"
  azs      = local.west_azs
  nat_mode = "single"

  tiers = {
    web = { type = "public", cidrs = ["10.2.0.0/24", "10.2.1.0/24"] }
    app = { type = "nat", cidrs = ["10.2.10.0/24", "10.2.11.0/24"] }
    db  = { type = "isolated", cidrs = ["10.2.40.0/24", "10.2.41.0/24"] }
  }

  enable_flow_logs = var.enable_flow_logs
  tags             = { Network = "oregon" }
}
