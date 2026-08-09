#SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

#CloudWatch Alarm for ASG
resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  alarm_name = "${var.project_name}-asg-high-cpu"

  alarm_description = "Alarm when ASG average CPU exceeds 80%"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = 300

  evaluation_periods = 2

  threshold = 80

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = local.common_tags
}

#Alarm for ALB
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name = "${var.project_name}-alb-unhealthy-hosts"

  alarm_description = "Alarm when ALB has unhealthy targets"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Maximum"
  period    = 60

  evaluation_periods = 2

  threshold = 0

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = local.common_tags
}

#CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "ASG CPU Utilization"

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "AutoScalingGroupName",
              aws_autoscaling_group.app.name
            ]
          ]

          period = 300
          stat   = "Average"
          region = var.aws_region

          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title = "ALB Request Count"

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.app.arn_suffix
            ]
          ]

          period = 300
          stat   = "Sum"
          region = var.aws_region

          view    = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}
