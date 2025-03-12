resource "aws_lb" "nlb" {
  name               = "nlb-for-api-gw"
  internal           = true
  load_balancer_type = "network"
  subnets            = [data.aws_subnet.subnet-lab-1.id, data.aws_subnet.subnet-lab-2.id]

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  protocol = "HTTP"
  port     = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}


resource "aws_lb_target_group" "nlb_tg" {
  name     = "nlb-tg"
  port     = 80
  protocol = "TCP"
  target_type = "alb"
  vpc_id   = data.aws_vpc.vpc-lab.id
}

resource "aws_lb_target_group_attachment" "nlb_tg_attachment" {
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  target_id        = aws_lb.api_alb.id
  port             = 80

  depends_on = [ aws_lb_target_group.api_tg ]
}