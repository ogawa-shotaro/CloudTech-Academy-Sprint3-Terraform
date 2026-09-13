# [セキュリティ] 各ルールに`description`を付けているのは、後から見た人が
# 「なぜこの通信を許可しているか」を追わなくて済むようにするため
# (checkov/tflintのようなセキュリティチェックツールもこの記述を推奨・要求する)。
#
# [Terraform構文] ここではSGのルールを、`aws_security_group`本体の中に書く
# 「インラインブロック(ingress/egress)」ではなく、独立したリソース
# (aws_vpc_security_group_ingress_rule / egress_rule)として書いている。
# 理由: ALB用SGとAPIサーバ用SGは「お互いのSGを参照し合う」関係にある
# (ALB→APIサーバへの送信 / APIサーバ→ALBからの受信)。もしこれをインライン
# ブロックで書くと、「ALBを作るにはAPIのIDが要る」「APIを作るにはALBのIDが
# 要る」という循環参照になりTerraformが解決できない。ルールを別リソースに
# することで、先に両方のSG(箱)を作ってから、後でお互いを参照するルールを
# 追加できるため、循環しない。

# ALB用SG: インターネットからのHTTP(80番)のみ受信・APIサーバへの送信のみ許可する
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound HTTP(80) from the internet"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# [修正] 以前はcidr_ipv4 = "0.0.0.0/0"(あらゆる宛先)にしていたが、これは
# description「To API servers」の意図(APIサーバ限定)と食い違っていた
# (インラインブロックのままだと循環参照になるため、IPアドレス指定で妥協していた)。
# 独立リソースにしたことで、実際にAPIサーバ用SGのIDだけに送信先を限定できる。
resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To API servers"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# APIサーバ用SG: ALBからの80番のみ受信(インターネットからの直接アクセスは拒否)。
# アウトバウンドはソフトウェアインストール等のため全許可(NAT Gateway経由)。
resource "aws_security_group" "api" {
  name        = "${local.name_prefix}-api-sg"
  description = "Allow HTTP(80) from the ALB only"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-api-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id = aws_security_group.api.id
  description       = "HTTP from ALB"
  # [セキュリティ] `cidr_ipv4`(IPアドレス範囲)ではなく`referenced_security_group_id`で
  # 許可先を指定している。これにより「IPアドレスが何であれ、ALBのSGが付いている
  # リソースからの通信だけ」を許可でき、インターネットからの直接アクセスは
  # (ALBを経由しない限り)一切通らない。
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "api_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Outbound for package installation (via NAT Gateway)"
  cidr_ipv4         = "0.0.0.0/0"
  # [Terraform構文] ip_protocol = "-1" は「全プロトコル・全ポート」を意味するAWSの
  # 特殊な指定値。全ポート対象のため from_port/to_port は指定しない。
  # ソフトウェアインストール等で使うポートを個別に絞らず、アウトバウンドは丸ごと許可している
  # (インバウンドは上のingressで80番のみに絞っているので、外部からの攻撃面はそちらで制御している)。
  ip_protocol = "-1"
}
