module "eventbridge" {
  source                   = "terraform-aws-modules/eventbridge/aws"
  create_bus               = false
  bus_name                 = "default" # use default bus generated by aws
  attach_cloudwatch_policy = true

  cloudwatch_target_arns = [
    aws_cloudwatch_log_group.event_bridge_log_group.arn
  ]

  rules = {
    s3_object_create = {
      description = "s3 object create rule",
      event_pattern = jsonencode({
        "source" : ["aws.s3"],
        "detail-type" : ["Object Created"],
        "detail" : {
          "bucket" : {
            "name" : [aws_s3_bucket.test_bucket.id]
          },
          "object" : {
            "key" : [{
              "wildcard" : "test/*.txt"
          }] }
        }
      })
    },
    custom_rule_schema = {
      description = "test custom schema"
      event_pattern = jsonencode({
        "detail" : {
          "bucket_name" : [{
            "exists" : true
          }],
          "message" : [{
            "exists" : true
          }],
          "result" : [{
            "exists" : true
          }]
        }
      })
    }
  }

  targets = {
    s3_object_create = [
      {
        name = "event-bridge-logs"
        arn  = aws_cloudwatch_log_group.event_bridge_log_group.arn
      },
      {
        name = "trigger-lambda"
        arn  = module.logging_lambda_func.lambda_function_arn
      }
    ],
    custom_rule_schema = [
      {
        name = "event-bridge-custom-schema-logs"
        arn  = aws_cloudwatch_log_group.event_bridge_log_group.arn
      },
      {
        name = "trigger-lambda-custom-schema"
        arn  = module.logging_lambda_func.lambda_function_arn
      }
    ]
  }
  depends_on = [aws_cloudwatch_log_group.event_bridge_log_group]

  tags = {
    Name = "test-eventbridge"
  }
}

/**
event is
{
    "version": "0",
    "id": "",
    "detail-type": "Object Created",
    "source": "aws.s3",
    "account": "",
    "time": "2025-03-19T23:30:03Z",
    "region": "us-east-1",
    "resources": [
        "arn:aws:s3:::bucketname"
    ],
    "detail": {
        "version": "0",
        "bucket": {
            "name": ""
        },
        "object": {
            "key": "",
            "size": 110916,
            "etag": "",
            "sequencer": ""
        },
        "request-id": "",
        "requester": "",
        "source-ip-address": "",
        "reason": "PutObject"
    }
}
*/
