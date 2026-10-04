resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${var.name_prefix}-web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_autoscaling_policy.web_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name          = "${var.name_prefix}-web-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60
  alarm_actions       = [aws_autoscaling_policy.web_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_west_cpu_high" {
  provider            = aws.west
  alarm_name          = "${var.name_prefix}-web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_autoscaling_policy.web_west_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_west.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_west_cpu_low" {
  provider            = aws.west
  alarm_name          = "${var.name_prefix}-web-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60
  alarm_actions       = [aws_autoscaling_policy.web_west_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_west.name
  }
}
