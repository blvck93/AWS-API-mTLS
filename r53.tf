resource "aws_route53_record" "dns" {
  zone_id = data.aws_route53_zone.blvckovh.id
  name    = "api.blvck.ovh"
  type    = "A"
  alias {
    name                   = aws_api_gateway_domain_name.custom.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.custom.cloudfront_zone_id
    evaluate_target_health = false
  }
}