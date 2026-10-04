resource "aws_internet_gateway" "production" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-production"
  }
}

resource "aws_internet_gateway" "development" {
  vpc_id = aws_vpc.development.id

  tags = {
    Name = "${var.name_prefix}-development"
  }
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name = "${var.name_prefix}-test"
  }
}

resource "aws_internet_gateway" "oregon" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id

  tags = {
    Name = "${var.name_prefix}-oregon"
  }
}
