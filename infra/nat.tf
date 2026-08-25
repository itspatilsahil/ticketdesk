# A self-managed NAT instance instead of a managed NAT Gateway.
#
# Why: a NAT Gateway bills ~$0.045/hr plus per-GB data processing from the
# moment it exists, free-tier or not. A t3.micro NAT instance rides on the
# same 750 free EC2 hours/month every new AWS account gets for 12 months,
# so it's effectively $0 for the life of this POC. The tradeoff (no
# managed failover, you patch the OS yourself) is a real one and is not
# how you'd do this in production - call that out explicitly in your
# cost/design report. This is exactly the kind of documented tradeoff
# the POC brief asks for.

resource "aws_security_group" "nat" {
  name        = "tkt-${var.owner_initials}-nat-sg"
  description = "NAT instance - allows outbound-driven traffic from private subnets only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic from inside the VPC (private subnets routing through this NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "NAT instance needs unrestricted outbound to reach the internet on behalf of private-subnet resources"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tkt-${var.owner_initials}-nat-sg" }
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  associate_public_ip_address = true

  # Fargate/RDS traffic arrives at this ENI addressed to other hosts, not
  # to the NAT instance itself - AWS drops that by default unless you
  # disable this check.
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    set -e
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
    iptables-save > /etc/sysconfig/iptables
  EOF

  tags = { Name = "tkt-${var.owner_initials}-nat-instance" }
}
