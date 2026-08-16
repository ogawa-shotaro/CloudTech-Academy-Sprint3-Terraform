# APIサーバ用セキュリティグループ: ALBからの80番のみ許可し、インターネットからの直接アクセスは拒否する
resource "aws_security_group" "api" {
  name        = "${var.name}-api-sg"
  description = "API server security group: allow HTTP(80) from ALB only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-api-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "Allow HTTP(80) from ALB security group only"
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# ソフトウェアインストール等のためのアウトバウンド通信(NAT Gateway経由)を許可する
resource "aws_vpc_security_group_egress_rule" "http_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Allow outbound HTTP(80) for package installation"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Allow outbound HTTPS(443) for package installation"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# SSH(22番)による直接ログインは許可しない(SG未定義=ALB以外からのインバウンドは全拒否)。
# 運用時のログインが必要な場合は、iam.tfで付与するSSM Session Manager用ロールを利用する。
