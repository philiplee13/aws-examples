/**
- create your own log group
- create log metric filter (this is what defines the pattern)
- create cloudwatch metric alarm
- create sns topic
- create sns topic subscription
*/
resource "aws_cloudwatch_metric_alarm" "foobar" {
  metric_name         = "test lamda error rate metric"
  namespace           = "testLambdaErrorNamespace"
  alarm_name          = "test-lambda-error-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  period              = 60
  statistic           = "Sum"
  alarm_description   = "test error in lambdas"
  treat_missing_data  = "missing"
}

resource "aws_cloudwatch_log_metric_filter" "yada" {
  name           = "testLambdaErrorCount"
  pattern        = "%ERROR%"
  log_group_name = aws_cloudwatch_log_group.custom_log_group.name

  metric_transformation {
    name      = "ErrorCount"
    namespace = "testLambdaErrorNamespace"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_group" "custom_log_group" {
  name = "testLambda"
}

