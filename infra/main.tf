terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

variable "aws_access_key" {}
variable "aws_secret_key" {}

# DynamoDB Table
resource "aws_dynamodb_table" "visitor_count_ddb" {
  name         = "cloudresume-test"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "visitors"
    type = "N"
  }

  tags = {
    Name = "Cloud Resume"
  }
}

# DynamoDB Table Item
resource "aws_dynamodb_table_item" "visitor_count_ddb_item" {
  table_name = aws_dynamodb_table.visitor_count_ddb.name
  hash_key   = aws_dynamodb_table.visitor_count_ddb.hash_key

  item = <<ITEM
{
  "id": {"S": "visitor_count"},
  "visitors": {"N": "1"}
}
ITEM
}

# Retrieve the current AWS region dynamically
data "aws_region" "current" {}

# Retrieve the current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Create Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name               = "cloudresume-test-api-role-rij7v4ll"
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

# Create Lambda IAM Role Policy
resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "DynamoDBAccessPolicy"
  path        = "/"
  description = "AWS IAM Policy for aws lambda to access dynamodb"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "dynamodb:BatchGetItem",
       "dynamodb:GetItem",
       "dynamodb:Query",
       "dynamodb:Scan",
       "dynamodb:BatchWriteItem",
       "dynamodb:PutItem",
       "dynamodb:UpdateItem"
     ],
     "Resource": "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/cloudresume-test"
   },
   {
     "Effect": "Allow",
     "Action": [
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
   },
   {
     "Effect": "Allow",
     "Action": "logs:CreateLogGroup",
     "Resource": "*"
   }
 ]
}
EOF
}

# IAM Role Policy Attachment to Lambda Role
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = cloudresume-test-api-role-rij7v4ll.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# Archive the Lambda function Python code
data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# Lambda function creation
resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = data.archive_file.zip_the_python_code.output_path
  function_name = "VisitorCounter"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  environment {
    variables = {
      databaseName = "cloudresume-test"
    }
  }
}

# Create API Gateway
resource "aws_apigatewayv2_api" "visitor_counter_api" {
  name          = "visitor_counter_http_api"
  protocol_type = "HTTP"
  description   = "Visitor counter HTTP API to invoke AWS Lambda function to update & retrieve the visitors count"
  cors_configuration {
      allow_credentials = false
      allow_headers     = []
      allow_methods     = [
          "GET",
          "OPTIONS",
          "POST",
      ]
      allow_origins     = [
          "*",
      ]
      expose_headers    = []
      max_age           = 0
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.visitor_counter_api.id
  name        = "default"
  auto_deploy = true
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "visitor_counter_api_integration" {
  api_id             = aws_apigatewayv2_api.visitor_counter_api.id
  integration_uri    = aws_lambda_function.terraform_lambda_func.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "any" {
  api_id   = aws_apigatewayv2_api.visitor_counter_api.id
  route_key = "ANY /VisitorCounter"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter_api_integration.id}"
}

# API Gateway Lambda Invocation Permission
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_counter_api.execution_arn}/*/*"
}

output "base_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/VisitorCounter"
}
