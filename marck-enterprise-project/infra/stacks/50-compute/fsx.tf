# AWS Organizations case study, task 1: a Linux file system mounted on two instances.
# FSx for OpenZFS is the lowest-cost FSx option for Linux NFS clients (64 GiB minimum).
# The production fleet (min 2 instances) mounts it at /mnt/shared.

resource "aws_security_group" "fsx" {
  count       = var.enable_fsx ? 1 : 0
  name        = "${var.project}-fsx"
  description = "NFS from the production web fleet"
  vpc_id      = local.net.prod.vpc_id
  tags        = { Name = "${var.project}-fsx" }
}

locals {
  nfs_ports = {
    "tcp-111"   = { protocol = "tcp", from = 111, to = 111 }
    "udp-111"   = { protocol = "udp", from = 111, to = 111 }
    "tcp-2049"  = { protocol = "tcp", from = 2049, to = 2049 }
    "udp-2049"  = { protocol = "udp", from = 2049, to = 2049 }
    "tcp-20001" = { protocol = "tcp", from = 20001, to = 20003 }
    "udp-20001" = { protocol = "udp", from = 20001, to = 20003 }
  }
}

resource "aws_vpc_security_group_ingress_rule" "fsx" {
  for_each = var.enable_fsx ? local.nfs_ports : {}

  security_group_id            = aws_security_group.fsx[0].id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from
  to_port                      = each.value.to
  referenced_security_group_id = local.net.prod.sg.app
}

resource "aws_vpc_security_group_egress_rule" "fsx" {
  count             = var.enable_fsx ? 1 : 0
  security_group_id = aws_security_group.fsx[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = local.net.prod.cidr
}

resource "aws_fsx_openzfs_file_system" "shared" {
  count = var.enable_fsx ? 1 : 0

  deployment_type     = "SINGLE_AZ_1"
  storage_capacity    = var.fsx_storage_gib
  throughput_capacity = 64
  subnet_ids          = [local.net.prod.subnet_ids["app1"][0]]
  security_group_ids  = [aws_security_group.fsx[0].id]

  automatic_backup_retention_days   = 7
  copy_tags_to_backups              = true
  daily_automatic_backup_start_time = "06:00"

  root_volume_configuration {
    data_compression_type = "LZ4"

    nfs_exports {
      client_configurations {
        clients = local.net.prod.cidr
        options = ["rw", "crossmnt", "no_root_squash"]
      }
    }
  }

  tags = { Name = "${var.project}-shared" }
}
