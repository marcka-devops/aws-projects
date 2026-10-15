# Module: web_fleet

An internet-facing Application Load Balancer in front of an Auto Scaling group, with the scaling rule from the ELB/ASG case study: add one instance when average CPU stays above 80% for 2 minutes, remove one when it stays below 60% for 5 minutes.

```hcl
module "fleet_east" {
  source = "../../modules/web_fleet"

  name                        = "marck-enterprise-web-east"
  vpc_id                      = local.net.prod.vpc_id
  alb_subnet_ids              = local.net.prod.subnet_ids["web"]
  instance_subnet_ids         = local.net.prod.subnet_ids["app1"]
  alb_security_group_id       = local.net.prod.sg.alb
  instance_security_group_ids = [local.net.prod.sg.app]
  ami_id                      = local.ami_east
  instance_profile_name       = aws_iam_instance_profile.instance.name
  certificate_arn             = aws_acm_certificate_validation.app_east[0].certificate_arn
  alarm_actions               = [local.alerts]
}
```

Pass a provider alias (`providers = { aws = aws.west }`) to build the same fleet in another region.

What it creates:

- ALB with HTTP → HTTPS redirect (or HTTP only when `certificate_arn` is null), TLS 1.3 policy, invalid headers dropped
- Target group with a `/health.php` health check
- Launch template: IMDSv2 required, encrypted gp3 root volume, detailed monitoring
- Auto Scaling group with ELB health checks and rolling instance refresh
- Scale-out and scale-in policies with their CPU alarms
- Optional 5xx and unhealthy-host alarms to `alarm_actions`

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | — | Name for the ALB, target group, launch template and group |
| `vpc_id` | `string` | — | VPC ID |
| `alb_subnet_ids` | `list(string)` | — | Public subnets for the ALB (two AZs or more) |
| `instance_subnet_ids` | `list(string)` | — | Subnets for the instances |
| `alb_security_group_id` | `string` | — | ALB security group |
| `instance_security_group_ids` | `list(string)` | — | Instance security groups |
| `ami_id` | `string` | — | AMI to launch |
| `instance_type` | `string` | `"t3.micro"` | Instance type |
| `root_volume_size` | `number` | `20` | Root volume in GiB |
| `instance_profile_name` | `string` | — | IAM instance profile |
| `user_data` | `string` | `""` | Plain-text user data |
| `min_size` / `max_size` / `desired_capacity` | `number` | `2` / `6` / `2` | Group size |
| `certificate_arn` | `string` | `null` | ACM certificate for HTTPS |
| `health_check_path` | `string` | `"/health.php"` | Target health check path |
| `scale_out_cpu` / `scale_in_cpu` | `number` | `80` / `60` | CPU thresholds |
| `alarm_actions` | `list(string)` | `[]` | SNS topics for ALB alarms |
| `enable_deletion_protection` | `bool` | `false` | ALB deletion protection |
| `tags` | `map(string)` | `{}` | Extra tags (propagated to instances) |

## Outputs

| Name | Description |
| --- | --- |
| `alb_arn`, `alb_dns_name`, `alb_zone_id` | Load balancer details |
| `target_group_name`, `target_group_arn` | Target group (used by CodeDeploy) |
| `asg_name` | Auto Scaling group name (used by CodeDeploy) |
