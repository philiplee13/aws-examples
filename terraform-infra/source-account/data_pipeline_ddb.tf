resource "random_id" "suffix" {
  byte_length = 4
}
resource "aws_dynamodb_table" "lambda_logs" {
  name         = "lambda-logs"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "function_name"
  range_key = "date"

  attribute {
    name = "function_name"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  tags = {
    Project     = "observability"
    Environment = "dev"
  }
}

# -------------------------
# Transformer Lambda (small decompressor + flattener)
# -------------------------
resource "aws_iam_role" "transformer_lambda_role" {
  name = "transformer_lambda_role_${random_id.suffix.hex}"

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

# Add inline policy for DynamoDB
resource "aws_iam_role_policy" "transformer_dynamodb" {
  role = aws_iam_role.transformer_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.lambda_logs.arn
      }
    ]
  })
}

# Lambda code: decode base64+gzip, parse CloudWatch envelope, output newline-delimited JSON
data "archive_file" "transformer_zip" {
  type        = "zip"
  output_path = "${path.module}/firehouse.zip"

  source {
    filename = "transformer.py"
    content  = <<EOF

import boto3
import json
import gzip
import base64
import time
from io import BytesIO
import re
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("lambda-logs")

def lambda_handler(event, context):
    print(f"event is {event}")
    compressed = base64.b64decode(event["awslogs"]["data"])
    with gzip.GzipFile(fileobj=BytesIO(compressed)) as gz:
        payload = json.loads(gz.read().decode("utf-8"))
        print(f"payload is {payload}")

        log_events = payload.get("logEvents", [])
        function_name = payload.get("logGroup", "UNKNOWN").split("/")[-1]
        logs = []
        metrics = []

        for log in log_events:
            message = log.get("message", "").strip()
            print(f"message is {message}")
            match = re.match(r"^\[\w+\]\s+\S+\s+\S+\s+(.*)", message)
            if match:
                cleaned = match.group(1).strip()
                print(f"cleaned is {cleaned}")
                ts = int(log.get("timestamp")) / 1000
                print(ts)
                dt_object = datetime.fromtimestamp(ts)
                print(dt_object)

                # Format the datetime object to YYYYMMDD string
                yyyymmdd_string = dt_object.strftime("%Y%m%d")
                print(yyyymmdd_string)

                # Decide if it's metric vs log
                # If payload is valid JSON → metric
                try:
                    metrics.append(json.loads(cleaned))
                except json.JSONDecodeError:
                    logs.append({"message": cleaned})
        
        item = {
            "function_name": function_name,
            "date": yyyymmdd_string,
            "message": logs,
            "metrics": metrics
        }
        print(f"putting item {item}")

        table.put_item(Item=item)

    return {"statusCode": 200}


EOF
  }
}

resource "aws_lambda_function" "transformer" {
  filename         = data.archive_file.transformer_zip.output_path
  function_name    = "transformer_decompress_${random_id.suffix.hex}"
  role             = aws_iam_role.transformer_lambda_role.arn
  handler          = "transformer.lambda_handler"
  runtime          = "python3.9"
  publish          = true
  source_code_hash = filebase64sha256(data.archive_file.transformer_zip.output_path)
  timeout          = 10
}

resource "aws_iam_role" "transformer_role" {
  name = "lambda-dynamodb-writer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "transformer_policy" {
  role = aws_iam_role.transformer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.lambda_logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}



#### TEST LAMBDA ####
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
    logger.info(json.dumps({"users_processed": "42"})) # shows as metric
    logger.info({"test": "value"}) # shows as log

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

resource "aws_cloudwatch_log_group" "transformer_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.transformer.function_name}"
  retention_in_days = 1
}


resource "aws_cloudwatch_log_subscription_filter" "lambda_logs_filter" {
  name            = "lambda-to-dynamodb"
  log_group_name  = "/aws/lambda/MyTestFunction"
  filter_pattern  = "" # empty = all events, or define JSON filter
  destination_arn = aws_lambda_function.transformer.arn
  depends_on      = [aws_cloudwatch_log_group.example_log_group]
}

resource "aws_lambda_permission" "allow_logs" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transformer.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.example_log_group.arn}:*"
}
