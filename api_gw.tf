resource "aws_api_gateway_rest_api" "api" {
  name        = "mtls-api"
  description = "API Gateway with mTLS and Lambda authorizer"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_domain_name" "custom" {
  domain_name     = "api.blvck.ovh"
  regional_certificate_arn = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_authorizer" "lambda" {
  name                   = "mtls-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = aws_lambda_function.auth_lambda.invoke_arn
  authorizer_result_ttl_in_seconds = 300
  type                   = "REQUEST"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda.id
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
  client_certificate_id = aws_api_gateway_client_certificate.client_cert.id
}

resource "aws_api_gateway_client_certificate" "client_cert" {
  description = "mTLS Trust Store Certificate"
}

resource "aws_s3_object" "trust_store" {
  bucket = "blvck9-c33rts00re2025"
  key    = "trust-store-cert.pem"
  source = "./trust-store-cert.pem"
}


resource "aws_api_gateway_mutual_tls_authentication" "mtls" {
  truststore_uri = "s3://blvck9-c33rts00re2025/trust-store-cert.pem"
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
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