resource "aws_api_gateway_rest_api" "api" {
  name        = "mtls-api"
  description = "API Gateway with mTLS and Lambda authorizer"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_domain_name" "api-blvck" {
  domain_name = "api.blvck.ovh"
  regional_certificate_arn = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
  
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_route53_record" "api-blvck-A" {
  name    = aws_api_gateway_domain_name.api-blvck.cloudfront_domain_name
  type    = "A"
  zone_id = aws_api_gateway_domain_name.api-blvck.cloudfront_zone_id
  alias {
    name                   = aws_api_gateway_domain_name.api-blvck.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api-blvck.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_authorizer" "lambda" {
  name                   = "LambdaAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = aws_lambda_function.auth_lambda.invoke_arn
  type                   = "TOKEN"
}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "mtls-auth-lambda"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_client_certificate" "client_cert" {
  description = "Client certificate for mTLS"
}

resource "aws_api_gateway_stage" "stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  client_certificate_id = aws_api_gateway_client_certificate.client_cert.id
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  domain_name = aws_api_gateway_domain_name.api-blvck.domain_name
}


data "archive_file" "lambda_package" {
  type        = "zip"
  output_path = "lambda.zip"

  source {
    content  = <<EOF
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
    filename = "index.py"
  }
}