terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Variable to define which AWS region resources will be deployed to. Set by default to 'us-east-1'.
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}


# Create an IAM role that only a Lambda function can assume.
resource "aws_iam_role" "mc_lambda_role" {
  name = "merapar_challenge-lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


# Attach the policy AWSLambdaBasicExecutionRole to the role "merapar_challenge-lambda_role" to allow Lambda to send logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "mc_lambda_policy" {
  role       = aws_iam_role.mc_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Create a custom policy to grant read access to the "merapar_challenge-dynamic_string" Systems Manager Parameter Store's parameter.
resource "aws_iam_policy" "mc_custompolicy_ssm_read" {
  name = "merapar_challenge-cp_ssm_read"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter"],
        Resource = aws_ssm_parameter.mc_dynamic_string.arn
      }
    ]
  })
}

# Attach the Custom Policy "merapar_challenge-cp_ssm_read" to the Role "merapar_challenge-lambda_role"
resource "aws_iam_role_policy_attachment" "attach_custompolicy_ssm_read" {
  role       = aws_iam_role.mc_lambda_role.name
  policy_arn = aws_iam_policy.mc_custompolicy_ssm_read.arn
}

# Create a parameter named "merapar_challenge-dynamic_string" in AWS Systems Manager (SSM) with the default value "dynamic string".
resource "aws_ssm_parameter" "mc_dynamic_string" {
  name  = "merapar_challenge-dynamic_string"
  type  = "String"
  value = "dynamic string"
}


# Pack up Python code of the Lambda function into a .zip file using Archive provider
data "archive_file" "mc_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda/function.zip"
}

resource "aws_lambda_function" "mc_lambda_function" {
  function_name    = "merapar_challenge-lambda_function"
  role             = aws_iam_role.mc_lambda_role.arn
  handler          = "merapar_challenge.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.mc_lambda_zip.output_path
  source_code_hash = data.archive_file.mc_lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128
}

# Create an API Gateway (HTTP)
resource "aws_apigatewayv2_api" "mc_http_api_gw" {
  name          = "merapar_challenge-api"
  protocol_type = "HTTP"
}

# Connect API Gateway to Lambda function using a proxy integration to forward the raw HTTP request to Lambda.
resource "aws_apigatewayv2_integration" "mc_lambda" {
  api_id                 = aws_apigatewayv2_api.mc_http_api_gw.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.mc_lambda_function.arn
  payload_format_version = "2.0"
  integration_method     = "POST"
}

# Map the method GET / to the Lambda integration previousy created.
resource "aws_apigatewayv2_route" "mc_api_route" {
  api_id    = aws_apigatewayv2_api.mc_http_api_gw.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.mc_lambda.id}"
}

# Deploy the API
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.mc_http_api_gw.id
  name        = "$default"
  auto_deploy = true
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "mc_perm_api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mc_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.mc_http_api_gw.execution_arn}/*/*"
}

# Output the API’s public endpoint URL
output "url" {
  description = "API Endpoint URL"
  value       = aws_apigatewayv2_api.mc_http_api_gw.api_endpoint
}
