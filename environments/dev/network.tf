# VPC本体
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  # [Terraform構文] merge(): 複数のmap(連想配列)を1つに結合する組み込み関数。
  # ここでは共通タグ(local.common_tags)に、このリソース固有の`Name`タグを追加している。
  # このファイル内で繰り返し出てくる`merge(local.common_tags, {...})`は全て同じ意図。
  tags = merge(local.common_tags, { Name = local.name_prefix })
}

# [セキュリティ] VPC作成時に自動で付与されるデフォルトセキュリティグループは、
# 誰が誤って使ってしまっても危険な穴が開かないよう、ingress/egressルールを
# 何も定義しない(=全トラフィック拒否)状態で明示的に管理する。
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-default-sg-restricted" })
}

# [Terraform構文] count: 同じ設定のリソースを、指定した数だけ繰り返し作成するための
# メタ引数。ここでは`public_subnet_cidrs`の要素数(=AZ数)だけサブネットを作る。
# `count.index`で「今何番目を作っているか(0, 1, 2...)」を取得し、対応するCIDR/AZを割り当てる。
# ALB用のパブリックサブネット(複数AZ)
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  # [セキュリティ] パブリックサブネットでも、EC2起動時にパブリックIPを自動付与しない設定。
  # (今回EC2自体はprivateサブネットに置くため実害は無いが、意図を明示するために書いている)
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index}" })
}

# APIサーバ用のプライベートサブネット(複数AZ)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-${count.index}" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

# [Terraform構文] ここも`count`(上記参照)。パブリックサブネットの数だけ関連付けを繰り返し、
# サブネット0番→関連付け0番、1番→1番、というように1対1で対応させている。
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# コスト優先のためNAT Gatewayは単一構成とする(全プライベートサブネットで共有)。
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat-eip" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
