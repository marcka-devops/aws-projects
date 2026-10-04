resource "aws_eip" "nat" {
  for_each = toset(["a", "b"])

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "production" {
  for_each = {
    a = aws_subnet.production["web_a"].id
    b = aws_subnet.production["web_b"].id
  }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value

  depends_on = [aws_internet_gateway.production]

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }
}
