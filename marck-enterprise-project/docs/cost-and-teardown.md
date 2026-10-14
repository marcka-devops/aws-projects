# Cost and teardown

## What it costs

Rough on-demand prices in us-east-1 and us-west-2, for 730 hours a month. Check the [AWS Pricing Calculator](https://calculator.aws/) before you apply; prices change.

| Item | Default | Approx. per month |
| --- | --- | --- |
| Aurora MySQL `db.r6g.large` | 2 in Virginia + 1 in Oregon | $570 |
| EC2 `t3.micro` | 2 + 2 fleet, 7 case-study instances, 1 Beanstalk | $90 |
| NAT gateways | 1 per VPC that needs one (prod, Oregon) | $66 + data |
| VPC interface endpoints | 3 services × 2 AZs | $44 |
| Application Load Balancers | 2 | $35 |
| Kinesis on-demand | 1 stream | $29 |
| FSx for OpenZFS | 64 GiB, 64 MB/s | $25 |
| ElastiCache Valkey `cache.t4g.micro` | 2 nodes | $23 |
| Global Accelerator | 1 | $18 + data |
| CloudFront, Route 53, Secrets Manager, CloudTrail, GuardDuty, CloudWatch | | $10–30 |
| **Total** | | **about $1,000** (≈ $1.40 an hour) |

### Cheaper settings

Set these before applying when you only need to demonstrate the design:

| Stack | Variable | Value | Saves |
| --- | --- | --- | --- |
| `30-data` | `primary_instance_count` | `1` | ~$190 |
| `30-data` | `enable_secondary_region` | `false` | ~$190 (no cross-region reads) |
| `10-network` | `enable_ssm_endpoints` | `false` | ~$44 (app2/db instances lose Session Manager) |
| `50-compute` | `enable_fsx` | `false` | ~$25 |
| `50-compute` | `enable_tier_instances` | `false` | ~$55 (drops the one-per-subnet instances and the QA target) |
| `50-compute` | `west_fleet_min` | `1` | ~$8 |

The budget in `20-security` emails `alert_email` at 80% of the forecast and 100% of actual spend (`monthly_budget_usd`, default $300).

## Teardown

Destroy in reverse order. Each step needs the stacks before it to still exist.

```bash
make destroy STACK=70-self-service
make destroy STACK=60-delivery
make destroy STACK=50-compute
make destroy STACK=40-storage
make destroy STACK=30-data
make destroy STACK=20-security
make destroy STACK=10-network
```

Things that need a hand first:

1. **Aurora deletion protection.** Set `deletion_protection = false` in `30-data`, apply, then destroy. A final snapshot `marck-enterprise-primary-final` is kept; delete it when you no longer need it.
2. **Buckets with objects.** The assets, website, analytics, config, catalog and CloudTrail buckets refuse to delete while they hold objects (artifact buckets empty themselves). Empty them, including old versions:
   ```bash
   aws s3 rm s3://<bucket> --recursive
   aws s3api delete-objects --bucket <bucket> --delete "$(aws s3api list-object-versions --bucket <bucket> \
     --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}}' --output json)"
   ```
3. **Service Catalog test stacks.** Terminate any provisioned products first. Their RDS instances, VPCs and DB subnets are retained on purpose; delete them by hand (turn off RDS deletion protection first).
4. **EBS snapshots.** Snapshots made by Data Lifecycle Manager (in both regions) and the golden AMIs stay after destroy. Deregister and delete them in both regions.
5. **The state bucket** (`00-bootstrap`) has `prevent_destroy`. Remove that line if you really want it gone, and delete it last.
