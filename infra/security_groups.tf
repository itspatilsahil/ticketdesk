resource "aws_security_group" "alb" {
  name        = "tkt-${var.owner_initials}-alb-sg"
  description = "Internet-facing ALB - the only thing allowed to talk to 0.0.0.0/0 inbound"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "tkt-${var.owner_initials}-alb-sg" }
}

resource "aws_security_group" "ecs_task" {
  name        = "tkt-${var.owner_initials}-ecs-sg"
  description = "ECS Fargate task - only reachable from the ALB security group (checklist item 12)"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "tkt-${var.owner_initials}-ecs-sg" }
}

# The two security groups above deliberately carry no inline ingress/egress
# blocks. alb.egress points at ecs_task and ecs_task.ingress points at alb -
# declaring both as inline rules on the security groups themselves creates a
# dependency cycle (Terraform can't create either SG before the other one
# exists). Declaring the cross-referencing rules as their own resources
# breaks the cycle: both security groups get created first (with no rules),
# then these four rules attach afterward.

resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description        = "Public HTTP"
  from_port          = 80
  to_port             = 80
  ip_protocol         = "tcp"
  cidr_ipv4           = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                   = "Forward to the ECS task only"
  from_port                     = var.container_port
  to_port                       = var.container_port
  ip_protocol                   = "tcp"
  referenced_security_group_id  = aws_security_group.ecs_task.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_task.id
  description                   = "From the ALB only - never a raw CIDR"
  from_port                     = var.container_port
  to_port                       = var.container_port
  ip_protocol                   = "tcp"
  referenced_security_group_id  = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs_task.id
  description        = "Outbound via the NAT instance to pull images, reach Secrets Manager/Parameter Store/S3, etc."
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}