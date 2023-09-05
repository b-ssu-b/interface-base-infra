provider "aws" {
  region = "ap-northeast-2"
}


# SNS topic 생성 
resource "aws_sns_topic" "rds_sns_topic" {
  name = "rds-sns-topic"
}

# lambda iam policy 생성 
resource "aws_iam_policy" "lambda_basic_policy" {
  name        = "lambada_basic_policy"
  path        = "/"
  description = "My lambda policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "*"
        }
    ]
  })
}

# lambda iam role 생성 
resource "aws_iam_role" "lambda_basic_role" {
  name = "test_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "lambda-basic-role"
  }
}

# lambda role attachment

resource "aws_iam_role_policy_attachment" "iam_lambda_attachment" {
  role       = aws_iam_role.lambda_basic_role.name
  policy_arn = aws_iam_policy.lambda_basic_policy.arn
}

# lambda 함수 생성 
resource "aws_lambda_function" "lambada_for_slack" {
  function_name = "lambda_function_name"
  role          = aws_iam_role.lambda_basic_role.arn
  handler       = "index.js"
  runtime       = "nodejs16.x"
  filename      = "lambdfunction.zip"
  source_code_hash = filebase64sha256("lambdfunction.zip")
  environment {
    variables = {
      webhook = "https://hooks.slack.com/services/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"
    }
  }  
}

# lambda permission 부여 
resource "aws_lambda_permission" "sns_permission" {
  statement_id  = "sns-trigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambada_for_slack.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.rds_sns_topic.arn
}

# lambda sns 구독 
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.rds_sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambada_for_slack.arn
}

# cloudwatch 경보 생성 
resource "aws_cloudwatch_metric_alarm" "Aurora_cluster_Seoul" {
  alarm_name                = "Aurora_cluster_Seoul"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 0.5
  alarm_description         = "Aurora_cluster_Seoul 의 Free Memory 가 0.5 이하입니다."
  dimensions = {
    DBClusterIdentifier = "aurora-cluster-seoul"
  }
  alarm_actions = [ aws_sns_topic.rds_sns_topic.arn ]
}