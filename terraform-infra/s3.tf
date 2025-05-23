resource "aws_s3_bucket" "test_bucket" {
  bucket = "lambda-source-test-bucket"
}

resource "aws_s3_bucket" "new_bucket" {
  bucket = "lambda-new-bucket"
}

resource "aws_s3_bucket_notification" "test_bucket_notification" {
  bucket      = aws_s3_bucket.test_bucket.id
  eventbridge = true # enables event bridge notifications

  // include filter prefix's and suffix's to narrow down files
  # lambda_function {
  #   lambda_function_arn = aws_lambda_function.test_lambda.arn
  #   events              = ["s3:ObjectCreated:*"]
  # }
}
