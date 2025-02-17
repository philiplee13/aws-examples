resource "aws_iam_role" "test_lambda_role" {
  name               = "test-lambda-role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "test_lambda_iam_policy" {

  name        = "test-lambda-iam-policy"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = file("policies/lambda-policy.json")
}

resource "aws_iam_policy" "test_lambda_s3_put_policy" {

  name        = "test-lambda-s3-put-iam-policy"
  path        = "/"
  description = "AWS IAM Policy for putting files into s3"
  policy = templatefile("policies/grant-s3-put-access.json", {
    bucketName = aws_s3_bucket.test_put_bucket.bucket
  })
}
resource "aws_iam_policy" "test_lambda_s3_get_policy" {

  name        = "test-lambda-s3-get-iam-policy"
  path        = "/"
  description = "AWS IAM Policy for getting files from s3"
  policy      = file("policies/get-s3-files.json")
}

resource "aws_iam_role_policy_attachment" "attach_base_lambda_policy_to_iam_role" {
  role       = aws_iam_role.test_lambda_role.name
  policy_arn = aws_iam_policy.test_lambda_iam_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_s3_put_policy_to_iam_role" {
  role       = aws_iam_role.test_lambda_role.name
  policy_arn = aws_iam_policy.test_lambda_s3_put_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_s3_get_policy_to_iam_role" {
  role       = aws_iam_role.test_lambda_role.name
  policy_arn = aws_iam_policy.test_lambda_s3_get_policy.arn
}
