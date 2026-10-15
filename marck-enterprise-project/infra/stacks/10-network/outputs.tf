output "domain_name" {
  value = var.domain_name
}

output "zone_id" {
  value = local.zone_id
}

output "name_servers" {
  description = "Set these at your domain registrar if Terraform created the zone."
  value       = local.name_servers
}

output "admin_cidr" {
  value = var.admin_cidr
}

output "prod" {
  value = {
    vpc_id       = module.prod_vpc.vpc_id
    cidr         = module.prod_vpc.cidr
    subnet_ids   = module.prod_vpc.subnet_ids
    subnet_cidrs = module.prod_vpc.subnet_cidrs
    sg = {
      alb      = aws_security_group.prod_alb.id
      app      = aws_security_group.prod_app.id
      web_tier = aws_security_group.prod_web_tier.id
      tier     = aws_security_group.prod_tier.id
      db       = aws_security_group.prod_db.id
      cache    = aws_security_group.prod_cache.id
    }
  }
}

output "dev" {
  value = {
    vpc_id       = module.dev_vpc.vpc_id
    cidr         = module.dev_vpc.cidr
    subnet_ids   = module.dev_vpc.subnet_ids
    subnet_cidrs = module.dev_vpc.subnet_cidrs
    sg = {
      web = aws_security_group.dev_web.id
      db  = aws_security_group.dev_db.id
    }
  }
}

output "west" {
  value = {
    vpc_id       = module.west_vpc.vpc_id
    cidr         = module.west_vpc.cidr
    subnet_ids   = module.west_vpc.subnet_ids
    subnet_cidrs = module.west_vpc.subnet_cidrs
    sg = {
      alb = aws_security_group.west_alb.id
      app = aws_security_group.west_app.id
      db  = aws_security_group.west_db.id
    }
  }
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.prod_dev.id
}
