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