# Infrastructure

Terraform for the whole platform, plus the CloudFormation template developers launch from Service Catalog.

```
infra/
├── modules/           Reusable building blocks
│   ├── vpc/           VPC with named subnet tiers, NAT, flow logs
│   ├── nacl/          Network ACL with numbered rules
│   └── web_fleet/     ALB + Auto Scaling group with CPU scaling alarms
├── stacks/            Root modules, applied in numeric order, one state file each
├── cloudformation/    Developer test-stack template (Service Catalog product)
└── settings.env.example
```

## Stacks

| Stack | State key | Reads | Creates |
| --- | --- | --- | --- |
| `00-bootstrap` | local | — | State bucket, GitHub OIDC provider, plan and apply roles |
| `10-network` | `network/` | — | 3 VPCs, peering, NACLs, security groups, endpoints, Route 53 zone |
| `20-security` | `security/` | — | IAM users/groups/policies, CloudTrail, GuardDuty, Access Analyzer, SNS, budget |
| `30-data` | `data/` | network, security | Aurora Global Database, secret, Valkey, Kinesis, analytics Lambda |
| `40-storage` | `storage/` | network, security | Assets bucket + Lambda trigger, website bucket, CloudFront, certificate |
| `50-compute` | `compute/` | network, security, data | Fleets (2 regions), ALBs, Global Accelerator, FSx, tier instances, EBS, DLM, Ansible |
| `60-delivery` | `delivery/` | network, security, compute | CodeCommit, CodeBuild, CodeDeploy, CodePipeline, Elastic Beanstalk |
| `70-self-service` | `self-service/` | security | Service Catalog portfolio, product and launch role |

Every stack has the same file layout:

| File | Holds |
| --- | --- |
| `versions.tf` | Terraform and provider version constraints, S3 backend (key only) |
| `providers.tf` | Provider configuration and `default_tags` |
| `variables.tf` | Inputs |
| `remote_state.tf` | Reads of other stacks' outputs, shared locals |
| `outputs.tf` | Values other stacks and people need |
| `<concern>.tf` | Resources grouped by what they do (`aurora.tf`, `fleets.tf`, …) |

## Running a stack

The backend bucket and region are passed at init, so no account details are committed:

```bash
make plan  STACK=30-data      # init + plan
make apply STACK=30-data      # init + apply (asks first)
```

Without Make:

```bash
terraform -chdir=infra/stacks/30-data init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="region=us-east-1"
terraform -chdir=infra/stacks/30-data apply
```

Inputs come from `TF_VAR_*` environment variables (see `settings.env.example`), so the same command works locally and in CI.

## Feature toggles

| Stack | Variable | Default | Effect when changed |
| --- | --- | --- | --- |
| `10-network` | `nat_mode` | `single` | `per_az` adds a NAT gateway per AZ |
| `10-network` | `enable_ssm_endpoints` | `true` | `false` removes Session Manager for app2/db |
| `30-data` | `enable_secondary_region` | `true` | `false` drops the Oregon Aurora cluster |
| `30-data` | `primary_instance_count` | `2` | `1` removes the Virginia reader |
| `50-compute` | `enable_https` | `true` | `false` serves HTTP only (no certificates) |
| `50-compute` | `enable_fsx` | `true` | `false` removes the shared file system |
| `50-compute` | `enable_tier_instances` | `true` | `false` removes the one-per-subnet instances and the QA target |
| `50-compute` | `golden_ami_name` | `""` | Set to use the Packer image instead of stock Amazon Linux |
| `60-delivery` | `source_provider` | `codecommit` | `github` reads GitHub directly through CodeConnections |
| `60-delivery` | `require_manual_approval` | `false` | `true` adds an approval between QA and production |
