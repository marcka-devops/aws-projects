locals {
  # MySQL database names and master usernames cannot contain hyphens.
  db_name = replace(var.name_prefix, "-", "")

  prod_subnets = {
    web_a     = { cidr = "10.0.0.0/24", az = var.primary_azs[0], tier = "web" }
    web_b     = { cidr = "10.0.1.0/24", az = var.primary_azs[1], tier = "web" }
    app1_a    = { cidr = "10.0.10.0/24", az = var.primary_azs[0], tier = "app1" }
    app1_b    = { cidr = "10.0.11.0/24", az = var.primary_azs[1], tier = "app1" }
    app2_a    = { cidr = "10.0.20.0/24", az = var.primary_azs[0], tier = "app2" }
    app2_b    = { cidr = "10.0.21.0/24", az = var.primary_azs[1], tier = "app2" }
    dbcache_a = { cidr = "10.0.30.0/24", az = var.primary_azs[0], tier = "dbcache" }
    dbcache_b = { cidr = "10.0.31.0/24", az = var.primary_azs[1], tier = "dbcache" }
    db_a      = { cidr = "10.0.40.0/24", az = var.primary_azs[0], tier = "db" }
    db_b      = { cidr = "10.0.41.0/24", az = var.primary_azs[1], tier = "db" }
  }

  dev_subnets = {
    web = { cidr = "10.1.0.0/24", az = var.primary_azs[0], tier = "web" }
    db  = { cidr = "10.1.10.0/24", az = var.primary_azs[0], tier = "db" }
  }

  test_subnets = {
    web  = { cidr = "10.3.0.0/24", az = var.primary_azs[0], tier = "web" }
    app  = { cidr = "10.3.10.0/24", az = var.primary_azs[0], tier = "app" }
    db_a = { cidr = "10.3.20.0/24", az = var.primary_azs[0], tier = "db" }
    db_b = { cidr = "10.3.21.0/24", az = var.primary_azs[1], tier = "db" }
  }

  oregon_subnets = {
    web_a = { cidr = "10.2.0.0/24", az = var.secondary_azs[0], tier = "web" }
    web_b = { cidr = "10.2.1.0/24", az = var.secondary_azs[1], tier = "web" }
    db_a  = { cidr = "10.2.10.0/24", az = var.secondary_azs[0], tier = "db" }
    db_b  = { cidr = "10.2.11.0/24", az = var.secondary_azs[1], tier = "db" }
  }
}
