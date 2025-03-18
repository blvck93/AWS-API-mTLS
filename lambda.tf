# Fetch the S3 object metadata 
data "aws_s3_object" "lambda_zip" {
  bucket = "blvck9-c33rts00re2025"
  key    = "lambda_function.zip"
}

resource "aws_lambda_function" "auth_lambda" {
  function_name    = "mtls-auth-lambda"
  role            = aws_iam_role.lambda_exec.arn
  runtime         = "python3.12"
  handler         = "lambda_function.lambda_handler"

  # Use S3 for Lambda deployment
  s3_bucket       = "blvck9-c33rts00re2025"
  s3_key          = "lambda_function.zip"

  # Get the base64 hash from S3 object (ensures updates on code changes)
  source_code_hash = data.aws_s3_object.lambda_zip.etag

  layers = [
    "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-cryptography:12"
  ]

  depends_on = [aws_iam_role.lambda_exec]
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

# data "archive_file" "lambda_package" {
#   type        = "zip"
#   output_path = "lambda.zip"
# 
#   source {
#     content  = <<EOF
# import hashlib
# from cryptography.hazmat.primitives import serialization
# from cryptography.x509 import load_pem_x509_certificate
# import base64
# 
# def calculate_thumbprint(pem_data: str, hash_algorithm: str = 'SHA-1') -> str:
#     """
#     Calculate certificate thumbprint from PEM-encoded data.
#     Defaults to SHA-1 (common for MTLS), but supports SHA-256.
#     """
#     # Load certificate from PEM
#     cert = load_pem_x509_certificate(pem_data.encode('utf-8'))
#     
#     # Get DER-encoded bytes
#     der_bytes = cert.public_bytes(encoding=serialization.Encoding.DER)
#     
#     # Calculate hash
#     if hash_algorithm.upper() == 'SHA-1':
#         digest = hashlib.sha1(der_bytes).digest()
#     elif hash_algorithm.upper() == 'SHA-256':
#         digest = hashlib.sha256(der_bytes).digest()
#     else:
#         raise ValueError(f"Unsupported hash algorithm: {hash_algorithm}")
#     
#     # Convert to hex string (uppercase without colons)
#     return digest.hex().upper()
# 
# def lambda_handler(event, context):
#     try:
#         # Extract client certificate from API Gateway event
#         client_cert_pem = event['requestContext']['identity']['clientCert']['clientCertPem']
#         
#         # Calculate thumbprint (default SHA-1)
#         thumbprint = calculate_thumbprint(client_cert_pem)
#         
#         return {
#             "principalId": "mtls-user",
#             "policyDocument": {
#                 "Version": "2012-10-17",
#                 "Statement": [{
#                     "Action": "execute-api:Invoke",
#                     "Effect": "Allow",
#                     "Resource": event['methodArn']
#                 }]
#             },
#             "context": {
#                 "certThumbprint": thumbprint
#             }
#         }
#     
#     except KeyError:
#         return {
#             "principalId": "anonymous",
#             "policyDocument": {
#                 "Version": "2012-10-17",
#                 "Statement": [{
#                     "Action": "execute-api:Invoke",
#                     "Effect": "Deny",
#                     "Resource": event['methodArn']
#                 }]
#             },
#             "context": {}
#         }
#   
#     except Exception as e:
#         print(f"Error processing certificate: {str(e)}")
#         raise
# 
# EOF
#     filename = "index.py"
#   }
# }