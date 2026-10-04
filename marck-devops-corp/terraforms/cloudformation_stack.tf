resource "aws_cloudformation_stack" "test" {
  name          = "${var.name_prefix}-app-test"
  template_body = file("${path.module}/files/cloudformation/test-stack.yaml")
  capabilities  = ["CAPABILITY_IAM"]

  parameters = {
    VpcId               = aws_vpc.test.id
    WebSubnetId         = aws_subnet.test["web"].id
    AppSubnetId         = aws_subnet.test["app"].id
    DbSubnetA           = aws_subnet.test["db_a"].id
    DbSubnetB           = aws_subnet.test["db_b"].id
    WebSecurityGroupId  = aws_security_group.test_web.id
    AppSecurityGroupId  = aws_security_group.test_app.id
    DbSecurityGroupId   = aws_security_group.test_db.id
    AmiId               = data.aws_ami.amazon_linux.id
    InstanceProfileName = aws_iam_instance_profile.instance.name
    NamePrefix          = var.name_prefix
    DbName              = local.db_name
  }
}
