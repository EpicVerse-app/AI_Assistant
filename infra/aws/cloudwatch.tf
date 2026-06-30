# ── CloudWatch Log Group ──────────────────────────────────────────────────────
# ECS streams container stdout/stderr here.
# With LOG_FORMAT=json, each line is a JSON object queryable via Logs Insights.
#
# Example Logs Insights query to find all errors:
#   fields @timestamp, level, logger, message
#   | filter level = "ERROR"
#   | sort @timestamp desc
#   | limit 50

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}/api"
  retention_in_days = 30 # reduce to 7 for cost savings, increase for compliance

  tags = { Name = "${var.project_name}-api-logs" }
}

# ── Optional: Metric filter — count ERROR log lines ───────────────────────────
# Creates a CloudWatch metric you can alarm on.

resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.api.name

  # Matches any JSON log line where "level" is "ERROR".
  pattern = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/API"
    value     = "1"
    unit      = "Count"
  }
}

# ── Optional: Alarm — fires if more than 10 errors in 5 minutes ───────────────
# Uncomment and set alarm_actions to an SNS topic ARN to get notified.

# resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
#   alarm_name          = "${var.project_name}-high-error-rate"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "ErrorCount"
#   namespace           = "${var.project_name}/API"
#   period              = 300
#   statistic           = "Sum"
#   threshold           = 10
#   alarm_description   = "More than 10 ERROR log lines in 5 minutes."
#   treat_missing_data  = "notBreaching"
#   # alarm_actions     = [aws_sns_topic.alerts.arn]
# }
