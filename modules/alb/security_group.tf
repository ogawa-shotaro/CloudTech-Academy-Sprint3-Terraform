# ALB用セキュリティグループ: インターネットからのHTTP(80番)受信のみ許可する
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group: allow inbound HTTP(80) from internet only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP(80) from internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "to_targets" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow forwarding to API server target port"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.target_port
  to_port           = var.target_port
  ip_protocol       = "tcp"
}
