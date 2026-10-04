data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux_west" {
  provider    = aws.west
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name_prefix}-web-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.web_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  network_interfaces {
    security_groups             = [aws_security_group.web.id]
    associate_public_ip_address = false
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/files/user-data.sh", {
    region    = var.primary_region
    fsx_dns   = aws_fsx_lustre_file_system.main.dns_name
    fsx_mount = aws_fsx_lustre_file_system.main.mount_name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name_prefix}-web"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "web_west" {
  provider      = aws.west
  name_prefix   = "${var.name_prefix}-web-"
  image_id      = var.ami_id_west != "" ? var.ami_id_west : data.aws_ami.amazon_linux_west.id
  instance_type = var.web_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  network_interfaces {
    security_groups             = [aws_security_group.web_west.id]
    associate_public_ip_address = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/files/user-data.sh", {
    region    = var.secondary_region
    fsx_dns   = ""
    fsx_mount = ""
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name_prefix}-web"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.name_prefix}-web"
  min_size                  = 2
  max_size                  = 6
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.production["web_a"].id, aws_subnet.production["web_b"].id]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "web_west" {
  provider                  = aws.west
  name                      = "${var.name_prefix}-web"
  min_size                  = 2
  max_size                  = 6
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.oregon["web_a"].id, aws_subnet.oregon["web_b"].id]
  target_group_arns         = [aws_lb_target_group.web_west.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_west.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_out" {
  name                   = "${var.name_prefix}-web-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "web_in" {
  name                   = "${var.name_prefix}-web-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "web_west_out" {
  provider               = aws.west
  name                   = "${var.name_prefix}-web-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web_west.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "web_west_in" {
  provider               = aws.west
  name                   = "${var.name_prefix}-web-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web_west.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}
