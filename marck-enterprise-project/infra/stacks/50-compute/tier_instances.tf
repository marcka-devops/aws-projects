# VPC case study: one instance in every subnet, named after the subnet it runs in.
# The production "web" instance also covers:
#   * EC2/EBS case study: two extra EBS volumes, resize/delete via var.ebs_volumes, daily snapshots
#   * Organizations case study: an extra network interface with its own public IP for SSH
#   * Automation case study: Ansible (through Systems Manager) serves a Hello World page on it
# The development "web" instance is the QA deployment target for the pipeline.

locals {
  tier_instances = var.enable_tier_instances ? {
    prod-web = {
      name = "web", network = "production", subnet = local.net.prod.subnet_ids["web"][0]
      sg   = local.net.prod.sg.web_tier, public = true, config = "true", role = "hello-world", deploy = "none"
    }
    prod-app1 = {
      name = "app1", network = "production", subnet = local.net.prod.subnet_ids["app1"][0]
      sg   = local.net.prod.sg.tier, public = false, config = "true", role = "tier", deploy = "none"
    }
    prod-app2 = {
      name = "app2", network = "production", subnet = local.net.prod.subnet_ids["app2"][0]
      sg   = local.net.prod.sg.tier, public = false, config = "false", role = "tier", deploy = "none"
    }
    prod-dbcache = {
      name = "dbcache", network = "production", subnet = local.net.prod.subnet_ids["dbcache"][0]
      sg   = local.net.prod.sg.tier, public = false, config = "true", role = "tier", deploy = "none"
    }
    prod-db = {
      name = "db", network = "production", subnet = local.net.prod.subnet_ids["db"][0]
      sg   = local.net.prod.sg.tier, public = false, config = "false", role = "tier", deploy = "none"
    }
    dev-web = {
      name = "web", network = "development", subnet = local.net.dev.subnet_ids["web"][0]
      sg   = local.net.dev.sg.web, public = true, config = "true", role = "qa", deploy = "qa"
    }
    dev-db = {
      name = "db", network = "development", subnet = local.net.dev.subnet_ids["db"][0]
      sg   = local.net.dev.sg.db, public = false, config = "false", role = "tier", deploy = "none"
    }
  } : {}
}

resource "aws_instance" "tier" {
  for_each = local.tier_instances

  ami                         = local.base_ami
  instance_type               = var.tier_instance_type
  subnet_id                   = each.value.subnet
  vpc_security_group_ids      = [each.value.sg]
  associate_public_ip_address = each.value.public
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  key_name                    = local.key_name
  monitoring                  = true

  # The QA instance runs the same web bootstrap as the production fleet.
  user_data = each.value.role == "qa" ? templatefile("${path.module}/templates/web-user-data.sh.tftpl", {
    region  = var.primary_region
    role    = "qa"
    fsx_dns = ""
  }) : null

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  tags = {
    Name            = each.value.name
    Network         = each.value.network
    Role            = each.value.role
    ConfigManaged   = each.value.config
    DeployGroup     = each.value.deploy
    CaseStudyTarget = each.key
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# ---------------------------------------------------------------------------
# Extra network interface with its own Elastic IP. SSH to that address reaches the instance.
# ---------------------------------------------------------------------------
resource "aws_network_interface" "web_secondary" {
  count = var.enable_tier_instances ? 1 : 0

  subnet_id       = local.net.prod.subnet_ids["web"][0]
  security_groups = [local.net.prod.sg.web_tier]
  description     = "Secondary interface for SSH (Organizations case study)"
  tags            = { Name = "web-eni-ssh" }
}

resource "aws_network_interface_attachment" "web_secondary" {
  count = var.enable_tier_instances ? 1 : 0

  instance_id          = aws_instance.tier["prod-web"].id
  network_interface_id = aws_network_interface.web_secondary[0].id
  device_index         = 1
}

resource "aws_eip" "web_secondary" {
  count = var.enable_tier_instances ? 1 : 0

  domain            = "vpc"
  network_interface = aws_network_interface.web_secondary[0].id
  tags              = { Name = "web-eni-ssh" }

  depends_on = [aws_network_interface_attachment.web_secondary]
}

# ---------------------------------------------------------------------------
# EBS volumes on the production web instance
# ---------------------------------------------------------------------------
resource "aws_ebs_volume" "web" {
  for_each = var.enable_tier_instances ? var.ebs_volumes : {}

  availability_zone = aws_instance.tier["prod-web"].availability_zone
  size              = each.value.size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name   = "web-${each.key}"
    Backup = "daily"
  }
}

resource "aws_volume_attachment" "web" {
  for_each = var.enable_tier_instances ? var.ebs_volumes : {}

  device_name = each.value.device
  volume_id   = aws_ebs_volume.web[each.key].id
  instance_id = aws_instance.tier["prod-web"].id
}

# Daily snapshots of every volume tagged Backup=daily, kept 7 days, copied to Oregon.
data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${var.project}-dlm"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "ebs" {
  description        = "Daily EBS snapshots with a copy in ${var.secondary_region}"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Backup = "daily" }

    schedule {
      name      = "daily"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["05:00"]
      }

      retain_rule {
        count = 7
      }

      cross_region_copy_rule {
        target    = var.secondary_region
        encrypted = true
        copy_tags = true
        retain_rule {
          interval      = 7
          interval_unit = "DAYS"
        }
      }
    }
  }
}
