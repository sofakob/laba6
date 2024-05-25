terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_s3_bucket" "source_bucket" {
  provider = aws.localstack
  bucket   = "source-bucket"
}

resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.localstack
  bucket   = "destination-bucket"
}

resource "aws_s3_bucket_lifecycle_configuration" "source_bucket_lifecycle" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.source_bucket.id

  rule {
    id     = "Move to Glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  provider = aws.localstack
  name     = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  provider  = aws.localstack
  role      = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_lambda_function" "s3_copy_function" {
  provider          = aws.localstack
  filename          = "lambda_function.zip"
  function_name     = "s3_copy_function"
  role              = aws_iam_role.lambda_role.arn
  handler           = "lambda_function.lambda_handler"
  runtime           = "python3.8"
  source_code_hash  = filebase64sha256("lambda_function.zip")
}

resource "aws_lambda_permission" "allow_s3_event" {
  provider        = aws.localstack
  statement_id    = "AllowExecutionFromS3Bucket"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.s3_copy_function.function_name
  principal       = "s3.amazonaws.com"
  source_arn      = aws_s3_bucket.source_bucket.arn
}

resource "aws_s3_bucket_notification" "s3_start_notification" {
  provider = aws.localstack
  bucket   = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_copy_function.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sns_topic" "notification_topic" {
  provider = aws.localstack
  name     = "notification-topic"
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  provider  = aws.localstack
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.s3_copy_function.arn
}
