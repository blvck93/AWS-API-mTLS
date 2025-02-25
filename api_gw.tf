resource "aws_api_gateway_rest_api" "api" {
  name        = "mtls-api"
  description = "API Gateway with mTLS and Lambda authorizer"
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_apigateway_domain_name" "api-blvck" {
  domain_name = "api.blvck.ovh"

  domain_name_configuration {
    certificate_arn = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  mutual_tls_authentication {
    truststore_uri = "s3://blvck9-c33rts00re2025/trust-store-cert.pem"
  }
}

resource "aws_route53_record" "api-blvck-A" {
  name    = aws_api_gateway_domain_name.api-blvck.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.blvckovh.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api-blvck.domain_name_configuration[0].target_domain_name
    zone_id                = aws_api_gateway_domain_name.api-blvck.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
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


resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  domain_name = aws_api_gateway_domain_name.api-blvck.domain_name
}