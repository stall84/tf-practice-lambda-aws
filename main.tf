
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"

}

provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "ms-simple-api"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

##########---------###########
# Actions to archive/zip lambda per aws reqs
##########---------###########

# Archive File type named 'init' will (describe) how our source code is zipped for aws
data "archive_file" "init" {

  type = "zip"

  source_dir  = path.module
  output_path = "/tmp/ms-simple-api.zip"

  excludes = [
    ".git",
    ".gitattributes",
    ".gitignore",
    ".idea",
    ".jshintrc",
    ".terraform",
    ".terraform.lock.hcl",
  ]
}

resource "aws_s3_object" "lambda_bucket_ms_simple" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "ms-simple-api.zip"
  source = data.archive_file.init.output_path

  etag = "testing"
}


##########---------###########
# Define the lambda function itself
##########---------###########

resource "aws_lambda_function" "lambda_ms_simple" {
  function_name = "LambdaMsSimple"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_bucket_ms_simple.key

  runtime = "nodejs12.x"
  handler = "handler.handler"

  source_code_hash = data.archive_file.init.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

# log group to store log messages from your lambda for 2 days

resource "aws_cloudwatch_log_group" "ec_random_notes" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_ms_simple.function_name}"
  retention_in_days = 2
}

# IAM role that allows Lambda to access resources in your AWS account

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# attaches a policy the IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#########################################
# gateway
#########################################
# defines a name for the API Gateway and sets its protocol to HTTP.
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

# application single stage  (test/prod...) for the API Gateway
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# configures the API Gateway to use your Lambda function.
resource "aws_apigatewayv2_integration" "ec_random_notes" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda_ms_simple.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# maps an HTTP request to a target, in
resource "aws_apigatewayv2_route" "ec_random_notes" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /notes"
  target    = "integrations/${aws_apigatewayv2_integration.ec_random_notes.id}"
}

#  log group to store access logs f
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 1
}

# API Gateway permission to invoke your Lambda function.
resource "aws_lambda_permission" "api_gw_random_notes" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_ms_simple.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Output value definitions

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name" {
  description = "Name of the EC notes random Lambda function."

  value = aws_lambda_function.ec_notes_random_notes.function_name
}

output "base_url_random_quote" {
  description = "random quote"
  value       = "curl ${aws_apigatewayv2_stage.lambda.invoke_url}/notes?action=random-quote"
}

output "base_url_today_date" {
  description = "today-date"
  value       = "curl ${aws_apigatewayv2_stage.lambda.invoke_url}/notes?action=today-date"
}
