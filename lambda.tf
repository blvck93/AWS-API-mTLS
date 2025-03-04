resource "aws_lambda_function" "auth_lambda" {
  function_name = "mtls-auth-lambda"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.8"
  handler       = "index.handler"
  filename      = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  depends_on = [data.archive_file.lambda_package]  # Ensures ZIP exists before Lambda is created
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
        "Service": ["apigateway.amazonaws.com","lambda.amazonaws.com"]
      },
      "Action": ["sts:AssumeRole","lambda:InvokeFunction"]
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