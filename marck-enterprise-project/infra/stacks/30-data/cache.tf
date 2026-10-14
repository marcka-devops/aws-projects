# Latency fix from the Database Architecture case study: branches keep asking for the same
# reports, so the app reads them from an in-memory cache before going to Aurora (cache-aside).

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project}-cache"
  subnet_ids = local.net.prod.subnet_ids["dbcache"]
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.project}-cache"
  description          = "Report cache for branch offices"

  engine               = "valkey"
  engine_version       = "8.0"
  parameter_group_name = "default.valkey8"
  node_type            = var.cache_node_type
  port                 = 6379

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [local.net.prod.sg.cache]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  snapshot_retention_limit   = 1
  snapshot_window            = "04:00-05:00"
}
