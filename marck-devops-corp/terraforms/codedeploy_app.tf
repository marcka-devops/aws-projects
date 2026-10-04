resource "aws_codedeploy_app" "web" {
  name             = "${var.name_prefix}-web"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "production" {
  app_name              = aws_codedeploy_app.web.name
  deployment_group_name = "production"
  service_role_arn      = aws_iam_role.codedeploy.arn
  autoscaling_groups    = [aws_autoscaling_group.web.name]

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.web.name
    }
  }
}

resource "aws_codedeploy_deployment_group" "qa" {
  app_name              = aws_codedeploy_app.web.name
  deployment_group_name = "qa"
  service_role_arn      = aws_iam_role.codedeploy.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "${var.name_prefix}-dev-web"
    }
  }

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }
}
