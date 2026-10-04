resource "aws_fsx_lustre_file_system" "main" {
  storage_capacity            = var.fsx_storage_capacity
  subnet_ids                  = [aws_subnet.production["app1_a"].id]
  security_group_ids          = [aws_security_group.fsx.id]
  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 125
  data_compression_type       = "LZ4"

  tags = {
    Name = "${var.name_prefix}-lustre"
  }
}
