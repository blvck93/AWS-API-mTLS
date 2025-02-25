resource "aws_apigatewayv2_domain_name" "api-blvck" {
  domain_name = "api.blvck.ovh"

  domain_name_configuration {
    certificate_arn = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
    endpoint_type   = "EDGE"
    security_policy = "TLS_1_2"
  }

  mutual_tls_authentication {
    truststore_uri = "s3://blvck9-c33rts00re2025/trust-store-cert.pem"
  }
}

resource "aws_route53_record" "dns" {
  zone_id = data.aws_route53_zone.blvckovh
  name    = aws_apigatewayv2_domain_name.api-blvck.domain_name
  type    = "A"
  alias {
    name                   = aws_api_gateway_domain_name.custom.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.custom.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

resource "aws_api_gateway_client_certificate" "client_cert" {
  description = "Client certificate for mTLS"
}

resource "aws_api_gateway_authorizer" "lambda" {
  name                   = "mtls-authorizer"
  rest_api_id            = aws_apigatewayv2_domain_name.api-blvck.id
  authorizer_uri         = aws_lambda_function.auth_lambda.invoke_arn
  authorizer_result_ttl_in_seconds = 300
  type                   = "REQUEST"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_apigatewayv2_domain_name.api-blvck.id
  resource_id   = aws_apigatewayv2_domain_name.api-blvck.root_resource_id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda.id
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_apigatewayv2_domain_name.api-blvck.id
  stage_name    = "prod"
  client_certificate_id = aws_api_gateway_client_certificate.client_cert.id
}


resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_apigatewayv2_domain_name.api-blvck.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  domain_name = aws_api_gateway_domain_name.custom.domain_name
}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "mtls_authorizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.8"

  source_code_hash = filebase64sha256("./lambda_function.py")

  filename = "lambda_function.py"

  inline_code = <<EOF
import json
def handler(event, context):
    headers = event.get('headers', {})
    client_cert = headers.get('x-client-cert')
    thumbprint = extract_thumbprint(client_cert) if client_cert else "Unknown"
    return {
        "isAuthorized": True,
        "context": {
            "thumbprint": thumbprint
        }
    }

def extract_thumbprint(cert):
    return cert[-40:]  # Simulated extraction
EOF
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

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

resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "lambda_basic_execution"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
