data "archive_file" "python_package" {
  type        = "zip"
  source_dir  = "${path.module}/code/"
  output_path = "${path.module}/code/package.zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename      = "${path.module}/code/package.zip"
  function_name = "test-lambda"
  role          = aws_iam_role.test_lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.12"
  timeout       = 10
  depends_on    = [aws_iam_role_policy_attachment.attach_base_lambda_policy_to_iam_role]
  logging_config {
    log_group  = aws_cloudwatch_log_group.custom_log_group.name
    log_format = "Text"
  }
}

resource "aws_lambda_permission" "s3-lambda-permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.test_bucket.arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.test_api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_sns.arn
}
