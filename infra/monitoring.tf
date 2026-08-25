# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/tkt-sp-task"
  retention_in_days = 7 # Free tier: keep logs for 7 days

  tags = {
    Name = "tkt-sp-ecs-logs"
  }
}

resource "aws_cloudwatch_log_stream" "ecs_stream" {
  name           = "tkt-sp-app"
  log_group_name = aws_cloudwatch_log_group.ecs_logs.name
}

# CloudWatch Alarm: ECS Task CPU
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "tkt-sp-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ECS CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "tkt-sp-ecs-cluster"
    ServiceName = "tkt-sp-ecs-service"
  }

  tags = {
    Name = "tkt-sp-ecs-cpu-alarm"
  }
}

# CloudWatch Alarm: ECS Task Memory
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "tkt-sp-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alert when ECS memory exceeds 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "tkt-sp-ecs-cluster"
    ServiceName = "tkt-sp-ecs-service"
  }

  tags = {
    Name = "tkt-sp-ecs-memory-alarm"
  }
}

# CloudWatch Alarm: ALB Unhealthy Targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "tkt-sp-alb-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when ALB has unhealthy targets"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "tkt-sp-alb-unhealthy-alarm"
  }
}

# CloudWatch Alarm: ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "tkt-sp-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0 # 1 second
  alarm_description   = "Alert when ALB target response time exceeds 1 second"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "tkt-sp-alb-response-time-alarm"
  }
}

# CloudWatch Alarm: ALB HTTP 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_http_5xx" {
  alarm_name          = "tkt-sp-alb-http-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when ALB receives 5 or more 5xx errors in 1 minute"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "tkt-sp-alb-5xx-alarm"
  }
}

# CloudWatch Alarm: RDS CPU
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "tkt-sp-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "tkt-sp-db"
  }

  tags = {
    Name = "tkt-sp-rds-cpu-alarm"
  }
}

# CloudWatch Alarm: RDS Database Connections
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "tkt-sp-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 15 # db.t3.micro default max is 20
  alarm_description   = "Alert when RDS connections exceed 15"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "tkt-sp-db"
  }

  tags = {
    Name = "tkt-sp-rds-connections-alarm"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "tkt-sp-poc-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "ECS CPU %" }],
            [".", "MemoryUtilization", { stat = "Average", label = "ECS Memory %" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Task Metrics"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }],
            [".", "UnHealthyHostCount", { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Target Health"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            [".", "TargetResponseTime", { stat = "Average" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            [".", "DatabaseConnections", { stat = "Average" }],
            [".", "FreeableMemory", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Database Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "fields @timestamp, @message | stats count() by @message"
          region  = var.aws_region
          title   = "ECS Log Insights"
        }
      }
    ]
  })
}

# Outputs
output "log_group_name" {
  value       = aws_cloudwatch_log_group.ecs_logs.name
  description = "CloudWatch Log Group for ECS"
}

output "dashboard_url" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
  description = "CloudWatch Dashboard URL"
}
