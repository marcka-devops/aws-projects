output "app_url" {
  value = "${var.enable_https ? "https" : "http"}://${local.app_host}"
}

output "global_accelerator_ips" {
  value = flatten([for s in aws_globalaccelerator_accelerator.app.ip_sets : s.ip_addresses])
}

output "alb_east_dns" {
  value = module.fleet_east.alb_dns_name
}

output "alb_west_dns" {
  value = module.fleet_west.alb_dns_name
}

output "asg_east_name" {
  value = module.fleet_east.asg_name
}

output "asg_west_name" {
  value = module.fleet_west.asg_name
}

output "target_group_east_name" {
  value = module.fleet_east.target_group_name
}

output "qa_instance_public_dns" {
  description = "QA deployment target in the development VPC."
  value       = var.enable_tier_instances ? aws_instance.tier["dev-web"].public_dns : null
}

output "web_tier_public_ip" {
  value = var.enable_tier_instances ? aws_instance.tier["prod-web"].public_ip : null
}

output "web_tier_eni_ip" {
  description = "SSH here: ssh ec2-user@<this ip> (Organizations case study, task 4)."
  value       = var.enable_tier_instances ? aws_eip.web_secondary[0].public_ip : null
}

output "tier_instance_ids" {
  value = { for k, i in aws_instance.tier : k => i.id }
}

output "fsx_dns_name" {
  value = var.enable_fsx ? aws_fsx_openzfs_file_system.shared[0].dns_name : null
}

output "instance_role_name" {
  value = aws_iam_role.instance.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.instance.name
}

output "config_bucket" {
  value = aws_s3_bucket.config.id
}
