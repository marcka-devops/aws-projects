output "vpc_id" {
  value = aws_vpc.this.id
}

output "cidr" {
  value = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Subnet IDs by tier, in AZ order."
  value = {
    for tier, cfg in var.tiers : tier => [for i in range(length(cfg.cidrs)) : aws_subnet.this["${tier}-${i}"].id]
  }
}

output "subnet_cidrs" {
  description = "Subnet CIDRs by tier, in AZ order."
  value       = { for tier, cfg in var.tiers : tier => cfg.cidrs }
}

output "route_table_ids" {
  description = "Route table IDs by tier, in AZ order."
  value = {
    for tier, cfg in var.tiers : tier => [for i in range(length(cfg.cidrs)) : aws_route_table.this["${tier}-${i}"].id]
  }
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}
