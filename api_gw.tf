resource "aws_api_gateway_rest_api" "api" {
  name        = "mtls-api"
  description = "API Gateway with mTLS and Lambda authorizer"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  mutual_tls_authentication {
    truststore_uri     = "s3://blvck9-c33rts00re2025/trust-store-cert.pem"
    truststore_version = "LATEST"
  }
}

resource "aws_api_gateway_domain_name" "api-blvck" {
  domain_name = "api.blvck.ovh"
  regional_certificate_arn = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "alb_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type = "HTTP"
  uri = "https://${aws_lb.alb.dns_name}"  # Replace with ALB DNS name

  request_parameters = {
    "integration.request.header.client-certificate" = "method.request.header.x-client-cert"
  }
}

resource "aws_lambda_function" "auth_lambda" {
  function_name = "mtls-auth-lambda"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  handler       = "index.handler"
  filename      = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  depends_on = [data.archive_file.lambda_package]  # Ensures ZIP exists before Lambda is created
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [aws_api_gateway_integration.lambda_integration]
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
import hashlib

def handler(event, context):
    headers = event.get('headers', {})
    client_cert = headers.get('x-client-cert')
    
    if client_cert:
        thumbprint = hashlib.md5(client_cert.encode()).hexdigest()
    else:
        thumbprint = "Unknown"

    return {
        "isAuthorized": True,
        "context": {
            "thumbprint": thumbprint
        }
    }
EOF
    filename = "index.py"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_exec_policy"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# resource "aws_route53_record" "api-blvck-A" {
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