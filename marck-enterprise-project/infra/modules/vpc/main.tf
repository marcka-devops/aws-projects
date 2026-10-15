locals {
  # One entry per subnet: "<tier>-<az index>" => settings. The az index also picks the NAT gateway.
  subnets = merge([
    for tier, cfg in var.tiers : {
      for i, cidr in cfg.cidrs : "${tier}-${i}" => {
        tier  = tier
        type  = cfg.type
        cidr  = cidr
        az    = var.azs[i]
        index = i
      }
    }
  ]...)

  public_tiers = sort([for tier, cfg in var.tiers : tier if cfg.type == "public"])
  public_tier  = length(local.public_tiers) > 0 ? local.public_tiers[0] : null
  has_nat_tier = anytrue([for cfg in values(var.tiers) : cfg.type == "nat"])

  nat_count = (var.nat_mode == "none" || !local.has_nat_tier || local.public_tier == null) ? 0 : (
    var.nat_mode == "single" ? 1 : length(var.tiers[local.public_tier].cidrs)
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })
}

# Lock down the default security group so nothing uses it by accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-default-locked" })
}

resource "aws_internet_gateway" "this" {
  count  = local.public_tier == null ? 0 : 1
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.type == "public"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value.tier}-${substr(each.value.az, -2, 2)}"
    Tier = each.value.tier
    Type = each.value.type
  })
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.this["${local.public_tier}-${count.index}"].id

  tags       = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on = [aws_internet_gateway.this]
}

# One route table per subnet keeps routing explicit and lets peering add routes to a single tier.
resource "aws_route_table" "this" {
  for_each = local.subnets

  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-${each.value.tier}-${substr(each.value.az, -2, 2)}-rt"
    Tier = each.value.tier
  })
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

resource "aws_route" "internet" {
  for_each = { for k, s in local.subnets : k => s if s.type == "public" }

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "nat" {
  for_each = { for k, s in local.subnets : k => s if s.type == "nat" && local.nat_count > 0 }

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.nat_mode == "single" ? 0 : each.value.index].id
}

# VPC Flow Logs to CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  tags              = var.tags
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix        = "${substr(var.name, 0, 24)}-flow-"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow_write" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow_write[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow[0].arn
  log_destination = aws_cloudwatch_log_group.flow[0].arn
  tags            = merge(var.tags, { Name = "${var.name}-flow-logs" })
}
