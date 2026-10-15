# Module: nacl

A network ACL attached to a set of subnets, with inbound and outbound rules given as lists. Rules are keyed by rule number, so reordering the list does not recreate them.

```hcl
module "nacl_db" {
  source     = "../../modules/nacl"
  name       = "marck-enterprise-prod-db"
  vpc_id     = module.prod_vpc.vpc_id
  subnet_ids = module.prod_vpc.subnet_ids["db"]

  ingress = [
    { rule_no = 100, protocol = "tcp", from_port = 3306, to_port = 3306, cidr = "10.0.0.0/16" },
    { rule_no = 110, protocol = "tcp", from_port = 1024, to_port = 65535, cidr = "10.0.0.0/16" },
  ]
  egress = [
    { rule_no = 100, protocol = "-1", cidr = "10.0.0.0/16" },
  ]
}
```

NACLs are stateless: allow the ephemeral range (1024–65535) for return traffic in whichever direction the connection did not start.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | — | Name tag |
| `vpc_id` | `string` | — | VPC ID |
| `subnet_ids` | `list(string)` | — | Subnets that use this ACL |
| `ingress` | `list(object)` | — | `rule_no`, `protocol` (`tcp`, `udp`, `icmp`, `-1`), `from_port`, `to_port`, `cidr`, `action` (default `allow`) |
| `egress` | `list(object)` | — | Same shape as `ingress` |
| `tags` | `map(string)` | `{}` | Extra tags |

## Outputs

| Name | Description |
| --- | --- |
| `id` | Network ACL ID |
