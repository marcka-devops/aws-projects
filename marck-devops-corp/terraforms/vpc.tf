resource "aws_vpc" "production" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-production"
    Environment = "production"
  }
}

resource "aws_vpc" "development" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-development"
    Environment = "development"
  }
}

resource "aws_vpc" "test" {
  cidr_block           = "10.3.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-test"
    Environment = "test"
  }
}

resource "aws_vpc" "oregon" {
  provider             = aws.west
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-oregon"
    Environment = "standby"
  }
}

resource "aws_default_security_group" "production" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "${var.name_prefix}-production-default"
  }
}

resource "aws_default_security_group" "development" {
  vpc_id = aws_vpc.development.id

  tags = {
    Name = "${var.name_prefix}-development-default"
  }
}

resource "aws_default_security_group" "test" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name = "${var.name_prefix}-test-default"
  }
}

resource "aws_default_security_group" "oregon" {
  provider = aws.west
  vpc_id   = aws_vpc.oregon.id

  tags = {
    Name = "${var.name_prefix}-oregon-default"
  }
}
