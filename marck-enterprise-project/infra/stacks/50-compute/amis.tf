# EC2/EBS case study, tasks 1-2: web servers come from an AMI, and the same image exists in Oregon.
# Packer (packer/web-ami.pkr.hcl) builds the image in us-east-1 and copies it to us-west-2.
# Until that image exists, the stock Amazon Linux 2023 AMI is used and user data installs the stack.

data "aws_ssm_parameter" "al2023_east" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "al2023_west" {
  provider = aws.west
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ami" "golden_east" {
  count       = var.golden_ami_name == "" ? 0 : 1
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.golden_ami_name}*"]
  }
}

data "aws_ami" "golden_west" {
  count       = var.golden_ami_name == "" ? 0 : 1
  provider    = aws.west
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.golden_ami_name}*"]
  }
}

locals {
  ami_east = var.golden_ami_name == "" ? nonsensitive(data.aws_ssm_parameter.al2023_east.value) : data.aws_ami.golden_east[0].id
  ami_west = var.golden_ami_name == "" ? nonsensitive(data.aws_ssm_parameter.al2023_west.value) : data.aws_ami.golden_west[0].id
  base_ami = nonsensitive(data.aws_ssm_parameter.al2023_east.value)
}
