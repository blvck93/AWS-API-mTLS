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
