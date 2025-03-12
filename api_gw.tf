## @@ ++ custom domain mapping stage
## @@ ++ header mapping from authenticator
## @@ ++ authorization as authenticator
## @@ ++ passtrough HTTP to alb (can be associated with R53 record)
## you can add additional security in accessing alb
## double check custom domain edge and mtls - it was not showing up https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-edge-optimized-custom-domain-name.html



resource "aws_api_gateway_rest_api" "api" {
  name        = "mtls-api"
  description = "API Gateway with mTLS and Lambda authorizer"
  disable_execute_api_endpoint = true ### required for custom domain api mapping!!

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_domain_name" "api-blvck" {
  domain_name = "api.blvck.ovh"
  regional_certificate_arn = data.aws_acm_certificate.cert-ext.arn
  security_policy = "TLS_1_2"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  mutual_tls_authentication {
    truststore_uri = "s3://${data.aws_s3_object.truststore_cert.bucket}/${data.aws_s3_object.truststore_cert.key}"
 #   truststore_version = "LATEST"
  }
}


resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda.id
}

resource "aws_api_gateway_integration" "alb_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_method.http_method
  integration_http_method = "ANY"
  type = "HTTP"
#  uri = "http://${aws_lb.api_alb.dns_name}"  
  uri         = "http://${aws_lb.nlb.dns_name}:80"
  connection_type = "VPC_LINK"
  connection_id    = aws_api_gateway_vpc_link.vpc_nlb.id
  
  request_templates = {
    "application/json" = <<EOF
{
    "body": $input.json('$'),
    "headers": {
        "X-Client-Thumbprint": "$context.authorizer.thumbprint"
    }
}
EOF
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}

resource "aws_api_gateway_vpc_link" "vpc_nlb" {
  name               = "vpc-to-nlb"
  description        = "VPC Link for API Gateway to reach NLB"
  target_arns        = [aws_lb.nlb.arn]
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [aws_api_gateway_integration.alb_integration]
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

  depends_on = [ aws_api_gateway_stage.stage ]
}

resource "aws_api_gateway_authorizer" "lambda" {
  name                   = "lambda"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = aws_lambda_function.auth_lambda.invoke_arn
  authorizer_credentials = aws_iam_role.lambda_exec.arn
  type                   = "TOKEN"
#  identity_source        = "method.request.header.x-client-cert"
}

resource "aws_api_gateway_account" "api_logging" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging.arn

  reset_on_delete = true
}

resource "aws_iam_role" "api_gateway_logging" {
  name = "APIGatewayLoggingRole"
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "api_logging_policy" {
  name       = "APIGatewayLoggingAttachment"
  roles      = [aws_iam_role.api_gateway_logging.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

#  resource "aws_route53_record" "api-blvck-A" {
#   name    = aws_api_gateway_domain_name.api-blvck.regional_domain_name
#   type    = "A"
#   zone_id = aws_api_gateway_domain_name.api-blvck.regional_zone_id
# 
#   alias {
#     name                   = aws_api_gateway_domain_name.api-blvck.regional_domain_name
#     zone_id                = aws_api_gateway_domain_name.api-blvck.regional_zone_id
#     evaluate_target_health = false
#   }
# }
# 
# resource "aws_iam_role_policy" "route53_policy" {
#   name = "route53_access_policy"
#   role = aws_iam_role.lambda_exec.id
#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "route53:ListHostedZones",
#         "route53:GetHostedZone",
#         "route53:ChangeResourceRecordSets",
#         "route53:ListResourceRecordSets"
#       ],
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }