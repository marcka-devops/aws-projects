resource "aws_subnet" "production" {
  for_each = local.prod_subnets

  vpc_id                  = aws_vpc.production.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "web"

  tags = {
    Name        = "${var.name_prefix}-prod-${each.key}"
    Environment = "production"
    Tier        = each.value.tier
  }
}

resource "aws_subnet" "development" {
  for_each = local.dev_subnets

  vpc_id                  = aws_vpc.development.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "web"

  tags = {
    Name        = "${var.name_prefix}-dev-${each.key}"
    Environment = "development"
    Tier        = each.value.tier
  }
}

resource "aws_subnet" "test" {
  for_each = local.test_subnets

  vpc_id                  = aws_vpc.test.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "web"

  tags = {
    Name        = "${var.name_prefix}-test-${each.key}"
    Environment = "test"
    Tier        = each.value.tier
  }
}

resource "aws_subnet" "oregon" {
  provider = aws.west
  for_each = local.oregon_subnets

  vpc_id                  = aws_vpc.oregon.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "web"

  tags = {
    Name        = "${var.name_prefix}-oregon-${each.key}"
    Environment = "standby"
    Tier        = each.value.tier
  }
}
