resource "aws_sns_topic" "email_sns" {
  name = "email_sns_trigger"
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn  = aws_sns_topic.email_sns.arn
  protocol   = "email"
  endpoint   = ""
  depends_on = [module.logging_lambda_func]
}
