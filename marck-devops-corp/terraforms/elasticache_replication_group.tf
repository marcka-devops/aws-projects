resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.name_prefix}-cache"
  subnet_ids = [aws_subnet.production["dbcache_a"].id, aws_subnet.production["dbcache_b"].id]
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id       = "${var.name_prefix}-cache"
  description                = "Repeated branch reads"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.cache_node_type
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  subnet_group_name          = aws_elasticache_subnet_group.cache.name
  security_group_ids         = [aws_security_group.cache.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis.result
  kms_key_id                 = aws_kms_key.primary.arn
}

resource "aws_secretsmanager_secret" "redis" {
  name       = "${var.name_prefix}/redis"
  kms_key_id = aws_kms_key.primary.arn
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis.result
    host       = aws_elasticache_replication_group.cache.primary_endpoint_address
    port       = 6379
  })
}

