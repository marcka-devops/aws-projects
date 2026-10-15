resource "aws_network_acl" "this" {
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = var.name })
}

resource "aws_network_acl_rule" "ingress" {
  for_each = { for r in var.ingress : tostring(r.rule_no) => r }

  network_acl_id = aws_network_acl.this.id
  egress         = false
  rule_number    = each.value.rule_no
  protocol       = each.value.protocol
  rule_action    = each.value.action
  cidr_block     = each.value.cidr
  from_port      = each.value.protocol == "-1" ? null : each.value.from_port
  to_port        = each.value.protocol == "-1" ? null : each.value.to_port
}

resource "aws_network_acl_rule" "egress" {
  for_each = { for r in var.egress : tostring(r.rule_no) => r }

  network_acl_id = aws_network_acl.this.id
  egress         = true
  rule_number    = each.value.rule_no
  protocol       = each.value.protocol
  rule_action    = each.value.action
  cidr_block     = each.value.cidr
  from_port      = each.value.protocol == "-1" ? null : each.value.from_port
  to_port        = each.value.protocol == "-1" ? null : each.value.to_port
}
