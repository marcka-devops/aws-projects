resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "${var.name_prefix}-aurora"
  engine                    = "aurora-mysql"
  engine_version            = var.aurora_engine_version
  storage_encrypted         = true
  deletion_protection       = true
}

resource "aws_db_subnet_group" "primary" {
  name       = "${var.name_prefix}-primary"
  subnet_ids = [aws_subnet.production["db_a"].id, aws_subnet.production["db_b"].id]
}

resource "aws_db_subnet_group" "west" {
  provider   = aws.west
  name       = "${var.name_prefix}-west"
  subnet_ids = [aws_subnet.oregon["db_a"].id, aws_subnet.oregon["db_b"].id]
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier          = "${var.name_prefix}-aurora-primary"
  engine                      = aws_rds_global_cluster.main.engine
  engine_version              = aws_rds_global_cluster.main.engine_version
  global_cluster_identifier   = aws_rds_global_cluster.main.id
  database_name               = local.db_name
  master_username             = local.db_name
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.primary.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  storage_encrypted           = true
  kms_key_id                  = aws_kms_key.primary.arn
  backup_retention_period     = 2
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "${var.name_prefix}-aurora-primary-final"
  copy_tags_to_snapshot       = true
}

resource "aws_rds_cluster_instance" "primary" {
  for_each = toset(["a", "b"])

  identifier           = "${var.name_prefix}-aurora-primary-${each.key}"
  cluster_identifier   = aws_rds_cluster.primary.id
  engine               = aws_rds_cluster.primary.engine
  engine_version       = aws_rds_cluster.primary.engine_version
  instance_class       = var.aurora_instance_class
  db_subnet_group_name = aws_db_subnet_group.primary.name
}

resource "aws_rds_cluster" "west" {
  provider                  = aws.west
  cluster_identifier        = "${var.name_prefix}-aurora-west"
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version
  global_cluster_identifier = aws_rds_global_cluster.main.id
  db_subnet_group_name      = aws_db_subnet_group.west.name
  vpc_security_group_ids    = [aws_security_group.db_west.id]
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.west.arn
  backup_retention_period   = 2
  deletion_protection       = true
  skip_final_snapshot       = true

  depends_on = [aws_rds_cluster_instance.primary]
}

resource "aws_rds_cluster_instance" "west" {
  provider             = aws.west
  identifier           = "${var.name_prefix}-aurora-west-a"
  cluster_identifier   = aws_rds_cluster.west.id
  engine               = aws_rds_cluster.west.engine
  engine_version       = aws_rds_cluster.west.engine_version
  instance_class       = var.aurora_instance_class
  db_subnet_group_name = aws_db_subnet_group.west.name
}

resource "aws_secretsmanager_secret" "aurora" {
  name        = "${var.name_prefix}/aurora"
  description = "Aurora writer endpoint. The master password is the secret RDS creates."
  kms_key_id  = aws_kms_key.primary.arn
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = aws_rds_cluster.primary.master_username
    host     = aws_rds_cluster.primary.endpoint
    port     = aws_rds_cluster.primary.port
    dbname   = aws_rds_cluster.primary.database_name
  })
}
