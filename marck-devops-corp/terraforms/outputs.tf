output "platform_role_arn" {
  value = aws_iam_role.platform.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "state_bucket" {
  value = aws_s3_bucket.platform["terraform-state"].id
}

output "lock_table" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "primary_alb_dns" {
  value = aws_lb.web.dns_name
}

output "standby_alb_dns" {
  value = aws_lb.web_west.dns_name
}

output "accelerator_dns" {
  value = aws_globalaccelerator_accelerator.app.dns_name
}

output "app_fqdn" {
  value = aws_route53_record.app.fqdn
}

output "www_fqdn" {
  value = aws_route53_record.www.fqdn
}

output "aurora_writer" {
  value = aws_rds_cluster.primary.endpoint
}

output "aurora_reader" {
  value = aws_rds_cluster.west.reader_endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.cache.primary_endpoint_address
}

output "breakglass_private_ip" {
  value = aws_network_interface.web_breakglass.private_ip
}

output "name_servers" {
  value = aws_route53_zone.public.name_servers
}
