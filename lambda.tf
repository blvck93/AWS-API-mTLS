resource "aws_lambda_function" "auth_lambda" {
  function_name = "mtls-auth-lambda"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  handler       = "index.handler"
  filename      = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  depends_on = [data.archive_file.lambda_package]  # Ensures ZIP exists before Lambda is created
}

# data "archive_file" "lambda_package" {
#   type        = "zip"
#   output_path = "lambda.zip"
# 
#   source {
#     content  = <<EOF
# import hashlib
# import json
# 
# def handler(event, context):
#     print("Received event:", json.dumps(event))  # Debugging logs
# 
#     headers = event.get('headers', {})
#     client_cert = headers.get('x-client-cert')
# 
#     if client_cert:
#         thumbprint = hashlib.md5(client_cert.encode()).hexdigest()
#     else:
#         thumbprint = "Unknown"
# 
#     return {
#         "principalId": thumbprint,  # Required for REST API authorizers
#         "policyDocument": {
#             "Version": "2012-10-17",
#             "Statement": [
#                 {
#                     "Action": "execute-api:Invoke",
#                     "Effect": "Allow",
#                     "Resource": event["methodArn"]  # Required for REST API
#                 }
#             ]
#         },
#         "context": {
#             "thumbprint": thumbprint
#         }
#     }
# 
# EOF
#     filename = "index.py"
#   }
# }

data "archive_file" "lambda_package" {
  type        = "zip"
  output_path = "lambda.zip"

  source {
    content  = <<EOF
import boto3
import hashlib
import base64
import OpenSSL

def calculate_md5_hash(thumbprint):
    """Calculate the MD5 hash of a given thumbprint."""
    return hashlib.md5(thumbprint.encode()).hexdigest()

def extract_thumbprint(cert_pem):
    """Extract the thumbprint from a certificate PEM."""
    cert = OpenSSL.crypto.load_certificate(OpenSSL.crypto.FILETYPE_PEM, cert_pem)
    thumbprint = OpenSSL.crypto.dump_certificate(OpenSSL.crypto.FILETYPE_PEM, cert).decode().strip()
    # Extract the actual thumbprint (SHA1 hash of the DER-encoded certificate)
    # This step may vary based on how you want to handle the thumbprint
    # Here, we directly use the SHA1 hash as the thumbprint for simplicity
    thumbprint_sha1 = hashlib.sha1(OpenSSL.crypto.dump_certificate(OpenSSL.crypto.FILETYPE_ASN1, cert)).hexdigest()
    return thumbprint_sha1

def lambda_handler(event, context):
    """Lambda authorizer function."""
    try:
        # Assuming event contains the certificate PEM or its thumbprint
        # Adjust based on actual event structure
        cert_pem = event.get('protocolData', {}).get('tls', {}).get('x509CertificatePem')
       
        if cert_pem:
            thumbprint = extract_thumbprint(cert_pem)
            md5_hash = calculate_md5_hash(thumbprint)
           
            # Return the MD5 hash as part of the authorization context
            return {
                'policyDocument': {
                    'Version': '2012-10-17',
                    'Statement': [
                        {
                            'Action': 'execute-api:Invoke',
                            'Resource': event['methodArn'],
                            'Effect': 'Allow'
                        }
                    ]
                },
                'context': {
                    'md5ThumbprintHash': md5_hash
                }
            }
        else:
            # Handle the case where the certificate PEM is not available
            return {
                'policyDocument': {
                    'Version': '2012-10-17',
                    'Statement': [
                        {
                            'Action': 'execute-api:Invoke',
                            'Resource': event['methodArn'],
                            'Effect': 'Deny'
                        }
                    ]
                }
            }
    except Exception as e:
        print(f"Error occurred: {e}")
        return {
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [
                    {
                        'Action': 'execute-api:Invoke',
                        'Resource': event['methodArn'],
                        'Effect': 'Deny'
                    }
                ]
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
        "Service": ["apigateway.amazonaws.com","lambda.amazonaws.com"]
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

resource "aws_iam_policy" "lambda_invoke_policy" {
  name        = "lambda_invoke_policy"
  description = "Allows API Gateway to invoke the Lambda function"
  
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_invoke_attachment" {
  policy_arn = aws_iam_policy.lambda_invoke_policy.arn
  role       = aws_iam_role.lambda_exec.name
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = aws_api_gateway_rest_api.api.execution_arn
}
