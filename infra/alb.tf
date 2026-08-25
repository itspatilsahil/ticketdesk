resource "aws_lb" "main" {
  name               = "tkt-${var.owner_initials}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Not a checklist item, but cheap insurance: stops someone fat-fingering
  # a console delete of your only public entry point mid-demo.
  enable_deletion_protection = false

  tags = { Name = "tkt-${var.owner_initials}-alb" }
}

resource "aws_lb_target_group" "api" {
  name        = "tkt-${var.owner_initials}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "tkt-${var.owner_initials}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
