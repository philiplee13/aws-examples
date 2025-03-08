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
  name              = "testLambda"
  retention_in_days = 1
}


// config for lambda terraform module
resource "aws_cloudwatch_metric_alarm" "logging_metric_alarm" {
  metric_name         = "Test Metric Alarm for Logging Lambda"
  namespace           = "logging-lambda-metrics"
  alarm_name          = "logging-lambda-error-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  period              = 300 # 5 minutes
  statistic           = "Sum"
  alarm_description   = "Testing for errors in logging lambda"
  treat_missing_data  = "missing"
}

resource "aws_cloudwatch_log_metric_filter" "logging_metric_filter" {
  name           = "logging-lambda-error-count"
  pattern        = "ERROR"
  log_group_name = module.logging_lambda_func.lambda_cloudwatch_log_group_name

  metric_transformation {
    name      = "error-count-for-logging-lambda"
    namespace = "logging-lambda-metrics"
    value     = "1"
  }
}
