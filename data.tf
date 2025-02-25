data "aws_vpc" "vpc-lab" {
  id = var.vpc_id.id
}

data "aws_subnet" "subnet-lab-1" {
  id = var.subnet_id.id
}

data "aws_subnet" "subnet-lab-2" {
  id = var.subnet2_id.id
}

data "aws_route53_zone" "blvckovh" {
  id = var.r53zone_id.id
}