module "eventbridge" {
  source                   = "terraform-aws-modules/eventbridge/aws"
  version                  = "3.14.3"
  create_bus               = false
  bus_name                 = "default" # use default bus generated by aws
  attach_cloudwatch_policy = true

  cloudwatch_target_arns = [
    module.log_group.cloudwatch_log_group_arn
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
          "app" : [{
            "equals-ignore-case" : "application1"
          }],
          "env" : [{
            "prefix" : "test-env"
            },
            {
              "prefix" : "qa-env"
          }],
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
        arn  = module.log_group.cloudwatch_log_group_arn
      },
    ],
    custom_rule_schema = [
      {
        name = "event-bridge-custom-schema-logs"
        arn  = module.log_group.cloudwatch_log_group_arn
      },
      // comment
    ]
  }
  depends_on = [module.log_group]

  tags = {
    Name = "test-eventbridge"
  }
}

/**
event for s3 file drop is
{
    "version": "0",
    "id": "",
    "detail-type": "Object Created",
    "source": "aws.s3",
    "account": "",
    "time": "2025-04-10T16:17:46Z",
    "region": "us-east-1",
    "resources": [
        "arn:aws:s3:::bucket-name"
    ],
    "detail": {
        "version": "0",
        "bucket": {
            "name": "bucket-name"
        },
        "object": {
            "key": "random.txt",
            "size": 0,
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
