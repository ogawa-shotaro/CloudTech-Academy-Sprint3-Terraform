# [セキュリティ] 各ingress/egressルールに`description`を付けているのは、
# 後から見た人が「なぜこの通信を許可しているか」を追わなくて済むようにするため
# (checkov/tflintのようなセキュリティチェックツールもこの記述を推奨・要求する)。
# ALB用SG: インターネットからのHTTP(80番)のみ許可する
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound HTTP(80) from the internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To API servers"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

# APIサーバ用SG: ALBからの80番のみ許可(インターネットからの直接アクセスは拒否)。
# アウトバウンドはソフトウェアインストール等のため全許可(NAT Gateway経由)。
resource "aws_security_group" "api" {
  name        = "${local.name_prefix}-api-sg"
  description = "Allow HTTP(80) from the ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # [セキュリティ] `cidr_blocks`(IPアドレス範囲)ではなく`security_groups`で許可先を指定している。
    # これにより「IPアドレスが何であれ、ALBのSGが付いているリソースからの通信だけ」を許可でき、
    # インターネットからの直接アクセスは(ALBを経由しない限り)一切通らない。
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound for package installation (via NAT Gateway)"
    from_port   = 0
    to_port     = 0
    # [Terraform構文] protocol = "-1" は「全プロトコル・全ポート」を意味するAWSの特殊な指定値。
    # ソフトウェアインストール等で使うポートを個別に絞らず、アウトバウンドは丸ごと許可している
    # (インバウンドは上のingressで80番のみに絞っているので、外部からの攻撃面はそちらで制御している)。
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-api-sg" })
}
