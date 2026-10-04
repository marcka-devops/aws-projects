resource "aws_network_interface" "web_breakglass" {
  subnet_id       = aws_subnet.production["web_a"].id
  security_groups = [aws_security_group.web.id]
  description     = "Break-glass SSH address. Attach it to a web instance only when Session Manager is unavailable."

  tags = {
    Name = "${var.name_prefix}-web-breakglass"
  }
}

resource "aws_security_group" "dbcache_host" {
  name_prefix = "${var.name_prefix}-dbcache-host-"
  description = "Named dbcache instance"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-dbcache-host" }
}

resource "aws_security_group" "db_host" {
  name_prefix = "${var.name_prefix}-db-host-"
  description = "Named database instance beside Aurora"
  vpc_id      = aws_vpc.production.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-db-host" }
}

resource "aws_vpc_security_group_ingress_rule" "dbcache_host_ssh" {
  security_group_id            = aws_security_group.dbcache_host.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "dbcache_host_https" {
  security_group_id = aws_security_group.dbcache_host.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_host_ssh" {
  security_group_id            = aws_security_group.db_host.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "db_host_https" {
  security_group_id = aws_security_group.db_host.id
  description       = "Session Manager through the interface endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.production.cidr_block
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.web_instance_type
  subnet_id                   = aws_subnet.production["web_a"].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-bastion"
  }
}

resource "aws_instance" "app1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.production["app1_a"].id
  vpc_security_group_ids = [aws_security_group.app1.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-app1"
  }
}

resource "aws_instance" "app2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.production["app2_a"].id
  vpc_security_group_ids = [aws_security_group.app2.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-app2"
  }
}

resource "aws_instance" "dbcache" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.production["dbcache_a"].id
  vpc_security_group_ids = [aws_security_group.dbcache_host.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-dbcache"
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.production["db_a"].id
  vpc_security_group_ids = [aws_security_group.db_host.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-db"
  }
}

resource "aws_instance" "dev_web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.web_instance_type
  subnet_id                   = aws_subnet.development["web"].id
  vpc_security_group_ids      = [aws_security_group.dev_web.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-dev-web"
  }
}

resource "aws_instance" "dev_db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.development["db"].id
  vpc_security_group_ids = [aws_security_group.dev_db.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-dev-db"
  }
}
