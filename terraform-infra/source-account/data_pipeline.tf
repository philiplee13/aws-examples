# S3 bucket for logs
resource "aws_s3_bucket" "observability" {
  bucket        = "my-firehose-test-logs-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

# IAM role that Firehose assumes to write to S3
resource "aws_iam_role" "firehose_role" {
  name = "firehose_to_s3_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "firehose.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Transformer Lambda

# -------------------------
# Transformer Lambda (small decompressor + flattener)
# -------------------------
resource "aws_iam_role" "transformer_lambda_role" {
  name = "firehose_transformer_lambda_role_${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transformer_lambda_basic" {
  role       = aws_iam_role.transformer_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda code: decode base64+gzip, parse CloudWatch envelope, output newline-delimited JSON
data "archive_file" "transformer_zip" {
  type        = "zip"
  output_path = "${path.module}/firehouse.zip"

  source {
    filename = "transformer.py"
    content  = <<EOF

import base64
import gzip
import json
import re
from io import BytesIO

def lambda_handler(event, context):
    output = []
    print(f"event is {event}")
    print(f"context is {context}")

    for record in event["records"]:
        try:
            # Base64 decode
            compressed_bytes = base64.b64decode(record["data"])

            # Decompress gzip
            with gzip.GzipFile(fileobj=BytesIO(compressed_bytes)) as gz:
                decompressed = gz.read().decode("utf-8")

            # CloudWatch delivers a JSON with logEvents
            payload = json.loads(decompressed)
            function_name = payload["logGroup"].split("/")[-1]

            logs = []
            metrics = []

            for log_event in payload.get("logEvents", []):
                message = log_event.get("message", "")

                # Match logger.* style: [LEVEL] timestamp reqId payload
                match = re.match(r"^\[\w+\]\s+\S+\s+\S+\s+(.*)", message)
                if match:
                    cleaned = match.group(1).strip()

                    # If payload is valid JSON → metric
                    try:
                        metrics.append(json.loads(cleaned))
                    except json.JSONDecodeError:
                        logs.append({"message": cleaned, "timestamp": log_event.get("timestamp")})

            # Build transformed object
            transformed_obj = {
                "function_name": function_name,
                "logs": logs,
                "metrics": metrics,
            }

            transformed = json.dumps(transformed_obj) + "\n"

            output.append({
                "recordId": record["recordId"],
                "result": "Ok",
                "data": base64.b64encode(transformed.encode("utf-8")).decode("utf-8")
            })

        except Exception as e:
            print(f"Transformer error: {e}")
            output.append({
                "recordId": record["recordId"],
                "result": "ProcessingFailed",
                "data": record["data"]
            })
    print(f"output is {output}")
    return {"records": output}


EOF
  }
}

resource "aws_lambda_function" "firehose_transformer" {
  filename         = data.archive_file.transformer_zip.output_path
  function_name    = "firehose_transformer_decompress_${random_id.suffix.hex}"
  role             = aws_iam_role.transformer_lambda_role.arn
  handler          = "transformer.lambda_handler"
  runtime          = "python3.9"
  publish          = true
  source_code_hash = filebase64sha256(data.archive_file.transformer_zip.output_path)
  timeout          = 10
}

# Allow Firehose service to invoke this Lambda (resource-based policy)
resource "aws_lambda_permission" "allow_firehose_invoke" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.firehose_transformer.function_name
  principal     = "firehose.amazonaws.com"
  # Restrict by source ARN (Firehose stream) for extra safety (set after stream is created)
  # note: we will use a depends_on to create permission after stream if necessary
  source_arn = aws_kinesis_firehose_delivery_stream.lambda_logs.arn
}

# IAM policy for Firehose → S3
resource "aws_iam_role_policy" "firehose_to_s3_policy" {
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.observability.arn,
          "${aws_s3_bucket.observability.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_invoke_lambda" {
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.firehose_transformer.arn
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "lambda_logs" {
  name        = "lambda-logs-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.observability.arn

    # Firehose requires >= 64MB when dynamic partitioning is enabled
    buffering_size     = 64
    buffering_interval = 60

    # Dynamic partitioning enabled
    dynamic_partitioning_configuration {
      enabled = true
    }

    processing_configuration {
      enabled = true

      # 1) Lambda processor - call our tiny decompressor
      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.firehose_transformer.arn
        }

        # optional: set retry options via parameters (omitted here)
      }

      # 2) MetadataExtraction: parse the flattened JSON lines emitted by transformer
      processors {
        type = "MetadataExtraction"

        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }

        # Extract function_name from logGroup; transformer preserves logGroup in each line
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{function_name:.function_name}"
        }
      }
    }

    prefix              = "function_name=!{partitionKeyFromQuery:function_name}/date=!{timestamp:yyyy}-!{timestamp:MM}-!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/lambda-logs"
      log_stream_name = "S3Delivery"
    }
  }
}

# IAM role for CloudWatch Logs to publish into Firehose
resource "aws_iam_role" "cwlogs_to_firehose" {
  name = "cwlogs_to_firehose_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cwlogs_to_firehose_policy" {
  role = aws_iam_role.cwlogs_to_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
        Resource = aws_kinesis_firehose_delivery_stream.lambda_logs.arn
      }
    ]
  })
}

# Example subscription filter for one Lambda log group
resource "aws_cloudwatch_log_subscription_filter" "lambda_logs" {
  name            = "lambda-to-firehose"
  log_group_name  = "/aws/lambda/MyTestFunction"
  destination_arn = aws_kinesis_firehose_delivery_stream.lambda_logs.arn
  role_arn        = aws_iam_role.cwlogs_to_firehose.arn
  filter_pattern  = "" # empty = all logs
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_test_2_logs" {
  name            = "lambda-to-firehose"
  log_group_name  = "/aws/lambda/MyTestFunction2"
  destination_arn = aws_kinesis_firehose_delivery_stream.lambda_logs.arn
  role_arn        = aws_iam_role.cwlogs_to_firehose.arn
  filter_pattern  = "" # empty = all logs
}


# Lambda execution role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Zip up the lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/code.zip"

  source {
    content  = <<EOF
import json
import time
import random
import logging

# Initialize the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO) # Set the desired logging level

def lambda_handler(event, context):
    # Generate a fake payload
    payload = {
        "request_id": context.aws_request_id,
        "function_name": context.function_name,
        "timestamp": time.time(),
        "random_value": random.randint(1, 100)
    }

    # CloudWatch captures all `print()` statements as logEvents
    logger.info("🔥 Hello from test Lambda!") # shows as log
    logger.info(json.dumps({"users_processed": 42})) # shows as metric
    logger.info({"test": "value"}) # shows as log

    return {"status": "ok", "payload": payload}

EOF
    filename = "lambda_function.py"
  }
}

# Lambda function
resource "aws_lambda_function" "test_lambda_2" {
  function_name = "MyTestFunction2"
  role          = aws_iam_role.lambda_exec_2.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.lambda_zip_2.output_path
}

# test lambda 2
resource "aws_iam_role" "lambda_exec_2" {
  name = "lambda2_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach_2" {
  role       = aws_iam_role.lambda_exec_2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Zip up the lambda code
data "archive_file" "lambda_zip_2" {
  type        = "zip"
  output_path = "${path.module}/lambda2.zip"

  source {
    content  = <<EOF
import json
import time
import random
import logging

# Initialize the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO) # Set the desired logging level

def lambda_handler(event, context):
    # Generate a fake payload
    payload = {
        "request_id": context.aws_request_id,
        "function_name": context.function_name,
        "timestamp": time.time(),
        "random_value": random.randint(1, 100)
    }

    # CloudWatch captures all `print()` statements as logEvents
    logger.info("hello from second lambda!") # shows as log
    logger.info(json.dumps({"tickets_processed": 21})) # shows as metric
    logger.info({"test from lambda 2": "value from lambda 22"}) # shows as log

    return {"status": "ok", "payload": payload}

EOF
    filename = "lambda_function.py"
  }
}

# Lambda function
resource "aws_lambda_function" "test_lambda" {
  function_name = "MyTestFunction"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.lambda_zip.output_path
}

resource "aws_cloudwatch_log_group" "example_log_group" {
  name              = "/aws/lambda/MyTestFunction"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "example_2_log_group" {
  name              = "/aws/lambda/MyTestFunction2"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "kinesis_log_group" {
  name              = "/aws/kinesisfirehose/lambda-logs"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "transformer_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.firehose_transformer.function_name}"
  retention_in_days = 1
}




/** ATHENA STUFF **/

data "aws_caller_identity" "current" {}
resource "aws_athena_database" "lambda_logs" {
  name          = "lambda_logs_db"
  bucket        = aws_s3_bucket.observability.bucket # your S3 bucket for query results
  force_destroy = true
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "my-athena-query-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_glue_catalog_table" "lambda_logs_table" {
  database_name = aws_athena_database.lambda_logs.name
  name          = "lambda_logs_and_metrics"

  parameters = {
    "projection.enabled"              = "true"
    "projection.function_name.type"   = "enum"
    "projection.function_name.values" = "${aws_lambda_function.test_lambda.function_name},${aws_lambda_function.test_lambda_2.function_name}"
    "projection.year.type"            = "integer"
    "projection.year.range"           = "2025,2030"
    "projection.month.type"           = "integer"
    "projection.month.range"          = "01,12"
    "projection.month.digits"         = "2"
    "projection.day.type"             = "integer"
    "projection.day.range"            = "01,31"
    "projection.day.digits"           = "2"
    "storage.location.template"       = "s3://${aws_s3_bucket.observability.bucket}/function_name=$${function_name}/date=$${year}-$${month}-$${day}/"
  }


  storage_descriptor {
    location      = "s3://${aws_s3_bucket.observability.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "logs"
      type = "array<struct<message:string,timestamp:bigint>>"
    }

    columns {
      name = "metrics"
      type = "array<map<string:string>>"
    }
  }

  partition_keys {
    name = "function_name"
    type = "string"
  }

  partition_keys {
    name = "date"
    type = "string"
  }
}
