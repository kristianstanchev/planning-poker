terraform {
  required_providers { aws = { source="hashicorp/aws" } }
}

provider "aws" { region = var.aws_region }

resource "aws_s3_bucket" "frontend" {
  bucket = var.s3_bucket_name
  acl    = "private"
  force_destroy = true
  website { index_document = "index.html" error_document = "index.html" }
}

resource "aws_cloudfront_origin_access_identity" "oai" { comment = "oai" }

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "s3-frontend"
    s3_origin_config { origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path }
  }
  enabled = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods = ["GET","HEAD"]
    target_origin_id = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values { query_string = false; cookies { forward="none" } }
  }
  viewer_certificate { cloudfront_default_certificate = true }
}

resource "aws_dynamodb_table" "rooms" {
  name = "${var.project_name}-rooms"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "roomId"
  attribute { name="roomId" type="S" }
}

resource "aws_dynamodb_table" "connections" {
  name = "${var.project_name}-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "connectionId"
  attribute { name="connectionId" type="S" }
  attribute { name="roomId" type="S" }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement { actions=["sts:AssumeRole"] principals { type="Service" identifiers=["lambda.amazonaws.com"] } }
}
resource "aws_iam_role" "lambda_role" { name = "${var.project_name}-lambda-role" assume_role_policy = data.aws_iam_policy_document.lambda_assume.json }

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:DeleteItem","dynamodb:Scan"]
    resources = [aws_dynamodb_table.rooms.arn, aws_dynamodb_table.connections.arn]
  }
  statement {
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    actions = ["execute-api:ManageConnections"]
    resources = ["arn:aws:execute-api:${var.aws_region}:*:*/*/POST/*"]
  }
}
resource "aws_iam_role_policy" "lambda_policy" { name = "pp-lambda-policy" role = aws_iam_role.lambda_role.id policy = data.aws_iam_policy_document.lambda_policy.json }

resource "aws_lambda_function" "ws" {
  filename = var.lambda_zip_path
  function_name = "${var.project_name}-ws"
  runtime = "nodejs18.x"
  handler = "handler.handler"
  role = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  environment { variables = { ROOMS_TABLE = aws_dynamodb_table.rooms.name CONNECTIONS_TABLE = aws_dynamodb_table.connections.name } }
}

resource "aws_apigatewayv2_api" "wsapi" {
  name = "${var.project_name}-ws"
  protocol_type = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}
resource "aws_apigatewayv2_integration" "lambda_integ" {
  api_id = aws_apigatewayv2_api.wsapi.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.ws.arn
}
resource "aws_apigatewayv2_route" "connect" { api_id = aws_apigatewayv2_api.wsapi.id route_key = "$connect" target = "integrations/${aws_apigatewayv2_integration.lambda_integ.id}" }
resource "aws_apigatewayv2_route" "disconnect" { api_id = aws_apigatewayv2_api.wsapi.id route_key = "$disconnect" target = "integrations/${aws_apigatewayv2_integration.lambda_integ.id}" }
resource "aws_apigatewayv2_route" "default" { api_id = aws_apigatewayv2_api.wsapi.id route_key = "$default" target = "integrations/${aws_apigatewayv2_integration.lambda_integ.id}" }

resource "aws_apigatewayv2_stage" "prod" { api_id = aws_apigatewayv2_api.wsapi.id name = "prod" auto_deploy = true }

resource "aws_lambda_permission" "apigw" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ws.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.wsapi.execution_arn}/*/*"
}

output "cloudfront_domain" { value = aws_cloudfront_distribution.cdn.domain_name }
output "s3_bucket" { value = aws_s3_bucket.frontend.bucket }
output "websocket_endpoint" { value = aws_apigatewayv2_api.wsapi.api_endpoint }
