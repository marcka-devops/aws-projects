output "aurora_writer_endpoint" {
  value = aws_rds_cluster.primary.endpoint
}

output "aurora_reader_endpoint" {
  value = aws_rds_cluster.primary.reader_endpoint
}

output "aurora_oregon_endpoint" {
  value = var.enable_secondary_region ? aws_rds_cluster.secondary[0].reader_endpoint : null
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "db_secret_name" {
  value = aws_secretsmanager_secret.db.name
}

output "cache_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "device_stream_name" {
  value = aws_kinesis_stream.device_events.name
}

output "device_stream_arn" {
  value = aws_kinesis_stream.device_events.arn
}

output "analytics_bucket" {
  value = aws_s3_bucket.analytics.id
}
