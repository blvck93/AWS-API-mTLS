data "aws_vpc" "vpc-lab" {
  id = var.vpc_id
}

data "aws_subnet" "subnet-lab-1" {
  id = var.subnet_id
}

data "aws_subnet" "subnet-lab-2" {
  id = var.subnet2_id
}

data "aws_route53_zone" "blvckovh" {
  name         = "blvck.ovh."
  private_zone = false
}