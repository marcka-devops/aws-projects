# Database Architecture case study.
#   1. Highly available, always-accessible database with 2-day automated backups:
#      Aurora MySQL, writer + reader across two AZs, automatic failover.
#   2. Read data from different regions: Aurora Global Database with a secondary in Oregon.
#      Write forwarding lets the Oregon app send writes without a separate connection string.

locals {
  db_name     = "marck"
  db_username = "marckadmin"
}

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#%^*()-_=+[]{}<>:?"
}

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = "${var.project}-global"
  engine                    = "aurora-mysql"
  engine_version            = var.aurora_engine_version
  database_name             = local.db_name
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
}

# ------------------------------- Virginia ----------------------------------
resource "aws_db_subnet_group" "primary" {
  name       = "${var.project}-primary"
  subnet_ids = local.net.prod.subnet_ids["db"]
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "${var.project}-primary"
  global_cluster_identifier = aws_rds_global_cluster.this.id
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  database_name             = local.db_name
  master_username           = local.db_username
  master_password           = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [local.net.prod.sg.db]

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:05:00-sun:06:00"
  copy_tags_to_snapshot        = true
  storage_encrypted            = true
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = false
  final_snapshot_identifier    = "${var.project}-primary-final"

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  lifecycle {
    ignore_changes = [master_password]
  }
}

resource "aws_rds_cluster_instance" "primary" {
  count = var.primary_instance_count

  identifier                   = "${var.project}-primary-${count.index}"
  cluster_identifier           = aws_rds_cluster.primary.id
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = aws_rds_cluster.primary.engine_version
  instance_class               = var.aurora_instance_class
  db_subnet_group_name         = aws_db_subnet_group.primary.name
  performance_insights_enabled = true
  auto_minor_version_upgrade   = true
}

# -------------------------------- Oregon -----------------------------------
data "aws_kms_alias" "rds_west" {
  provider = aws.west
  name     = "alias/aws/rds"
}

resource "aws_db_subnet_group" "secondary" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.west

  name       = "${var.project}-secondary"
  subnet_ids = local.net.west.subnet_ids["db"]
}

resource "aws_rds_cluster" "secondary" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.west

  cluster_identifier             = "${var.project}-secondary"
  global_cluster_identifier      = aws_rds_global_cluster.this.id
  engine                         = aws_rds_global_cluster.this.engine
  engine_version                 = aws_rds_global_cluster.this.engine_version
  enable_global_write_forwarding = true

  db_subnet_group_name   = aws_db_subnet_group.secondary[0].name
  vpc_security_group_ids = [local.net.west.sg.db]

  storage_encrypted       = true
  kms_key_id              = data.aws_kms_alias.rds_west.target_key_arn
  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = true

  depends_on = [aws_rds_cluster_instance.primary]

  lifecycle {
    ignore_changes = [replication_source_identifier, global_cluster_identifier]
  }
}

resource "aws_rds_cluster_instance" "secondary" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.west

  identifier                 = "${var.project}-secondary-0"
  cluster_identifier         = aws_rds_cluster.secondary[0].id
  engine                     = aws_rds_cluster.secondary[0].engine
  engine_version             = aws_rds_cluster.secondary[0].engine_version
  instance_class             = var.aurora_instance_class
  db_subnet_group_name       = aws_db_subnet_group.secondary[0].name
  auto_minor_version_upgrade = true
}

# ------------------------- connection details ------------------------------
# Stored once in Virginia and replicated to Oregon so both fleets read it locally.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/aurora/app"
  description             = "Aurora connection details for the web fleets"
  recovery_window_in_days = 7

  dynamic "replica" {
    for_each = var.enable_secondary_region ? [var.secondary_region] : []
    content {
      region = replica.value
    }
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine       = "mysql"
    username     = local.db_username
    password     = random_password.master.result
    dbname       = local.db_name
    port         = 3306
    writer_host  = aws_rds_cluster.primary.endpoint
    reader_host  = aws_rds_cluster.primary.reader_endpoint
    oregon_host  = var.enable_secondary_region ? aws_rds_cluster.secondary[0].reader_endpoint : null
    cache_host   = aws_elasticache_replication_group.this.primary_endpoint_address
    cache_reader = aws_elasticache_replication_group.this.reader_endpoint_address
  })
}

resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project}-aurora-cpu"
  alarm_description   = "Aurora writer CPU above 80% for 10 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier }
  alarm_actions       = [local.alerts]
}
