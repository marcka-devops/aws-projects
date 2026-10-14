# Module: vpc

A VPC whose subnets are declared as named tiers. Each tier lists one CIDR per Availability Zone and says how it reaches the internet. Every subnet gets its own route table, so a single tier can receive extra routes (for example, peering).

```hcl
module "prod_vpc" {
  source = "../../modules/vpc"

  name     = "marck-enterprise-prod"
  cidr     = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]
  nat_mode = "single"

  tiers = {
    web = { type = "public",   cidrs = ["10.0.0.0/24", "10.0.1.0/24"] }
    app = { type = "nat",      cidrs = ["10.0.10.0/24", "10.0.11.0/24"] }
    db  = { type = "isolated", cidrs = ["10.0.40.0/24", "10.0.41.0/24"] }
  }
}
```

| Tier type | Route |
| --- | --- |
| `public` | `0.0.0.0/0` → internet gateway; instances get public IPs |
| `nat` | `0.0.0.0/0` → NAT gateway in the same AZ (`per_az`) or the first one (`single`) |
| `isolated` | No route out of the VPC |

The module also locks down the default security group and, by default, sends VPC Flow Logs to CloudWatch Logs.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | — | Name and prefix for every resource |
| `cidr` | `string` | — | VPC CIDR block |
| `azs` | `list(string)` | — | AZs in order; a tier's Nth CIDR goes in `azs[N]` |
| `tiers` | `map(object({ cidrs = list(string), type = string }))` | — | Subnet tiers |
| `nat_mode` | `string` | `"single"` | `none`, `single` or `per_az` |
| `enable_flow_logs` | `bool` | `true` | Send flow logs to CloudWatch Logs |
| `flow_log_retention_days` | `number` | `30` | Flow log retention |
| `tags` | `map(string)` | `{}` | Extra tags |

## Outputs

| Name | Description |
| --- | --- |
| `vpc_id` | VPC ID |
| `cidr` | VPC CIDR |
| `subnet_ids` | Map of tier → subnet IDs in AZ order |
| `subnet_cidrs` | Map of tier → CIDRs in AZ order |
| `route_table_ids` | Map of tier → route table IDs in AZ order |
| `nat_gateway_ids` | NAT gateway IDs |
