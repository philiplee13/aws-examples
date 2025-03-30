module "synchrnous_s3_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "synchronous-s3"
  description   = "test for s3 synchrnous calls"
  handler       = "sync.handler"
  runtime       = "python3.12"

  source_path                       = "code-samples/async-vs-sync" # this renders out to be the root directory of the project -> so just go from there
  logging_log_format                = "JSON"
  logging_application_log_level     = "INFO"
  cloudwatch_logs_retention_in_days = 1
  timeout                           = 300
  ephemeral_storage_size            = 6000
}

module "async_s3_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "async-s3"
  description   = "test for s3 async calls"
  handler       = "async.handler"
  runtime       = "python3.12"

  source_path                       = "code-samples/async-vs-sync" # this renders out to be the root directory of the project -> so just go from there
  logging_log_format                = "JSON"
  logging_application_log_level     = "INFO"
  cloudwatch_logs_retention_in_days = 1
  timeout                           = 300
  ephemeral_storage_size            = 6000
  layers = [
    module.lambda_layer.lambda_layer_arn,
  ]
}
// worked with 5gb file at 512 mb

module "lambda_layer" {
  source = "terraform-aws-modules/lambda/aws"

  create_layer = true

  layer_name          = "lambda-layer"
  description         = "lambda layer"
  compatible_runtimes = ["python3.12"]

  source_path = "layers"
}
