data "aws_vpc" "vpc-lab" {
  id = var.vpc_id
}

data "aws_subnet" "subnet-lab-1" {
  id = var.subnet_id
}

data "aws_subnet" "subnet-lab-2" {
  id = var.subnet2_id
}

data "aws_api_gateway_domain_name" "domain-ext" {
  domain_name = var.domain_name
}

data "aws_acm_certificate" "cert-ext" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

data "aws_s3_object" "truststore_cert" {
  bucket = "blvck9-c33rts00re2025"
  key    = "trust-store-cert-github.pem"
}

data "aws_route53_zone" "blvckovh" {
  name         = "blvck.ovh."
  private_zone = false
}