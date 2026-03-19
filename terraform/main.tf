terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend values are supplied via backend.hcl (copied from backend.hcl.example).
  # Run: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  function_name = "jira-dod-webhook"
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_lambda_function" "jira_webhook" {
  function_name    = local.function_name
  filename         = "${path.module}/../dist/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../dist/lambda.zip")
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      JIRA_BASE_URL   = var.jira_base_url
      JIRA_USER_EMAIL = var.jira_user_email
      JIRA_API_TOKEN  = var.jira_api_token
    }
  }
}

# ── API Gateway HTTP API ───────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "jira_webhook" {
  name          = local.function_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.jira_webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.jira_webhook.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.jira_webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.jira_webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jira_webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.jira_webhook.execution_arn}/*/*"
}
