# modules/vpc-routing

`modules/vpc` で作成したVPC/サブネットに対して、インターネット疎通(IGW・NAT Gateway・ルートテーブル)を追加するモジュール。

## 提供する機能
- Internet Gateway(VPCにアタッチ)
- パブリックサブネット用ルートテーブル(0.0.0.0/0 → IGW)、全パブリックサブネットに関連付け
- NAT Gateway(**単一構成**。先頭のパブリックサブネットにのみ配置)+ EIP
- プライベートサブネット用ルートテーブル(0.0.0.0/0 → NAT Gateway)、全プライベートサブネットに関連付け

## 使用例

```hcl
module "vpc_routing" {
  source = "../../modules/vpc-routing"

  name                = "myproject-dev"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids

  tags = local.common_tags
}
```

## セキュリティ・コスト上の注意点
- NAT Gatewayはコスト最適化のため**単一構成**とする。NAT Gatewayを配置したAZに障害が発生した場合、他AZのプライベートサブネットからのアウトバウンド通信も影響を受ける(単一障害点)。高可用性が必要な本番環境では、AZごとにNAT Gateway/EIP/プライベートルートテーブルを分離する構成に変更すること。
- 本モジュールは疎通経路のみを扱い、セキュリティグループ等のアクセス制御は各モジュール(`modules/alb`, `modules/asg-api` 等)側で行う。

## Inputs / Outputs
`variables.tf` / `outputs.tf` を参照。全ての変数・出力に `description` を付与している。
