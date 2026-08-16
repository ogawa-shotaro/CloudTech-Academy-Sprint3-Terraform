# modules/asg-api

おみくじAPIサーバ(EC2)をAuto Scalingで運用するモジュール。Amazon Linux 2023 / `t2.micro` を前提とし、ALBのターゲットグループへ自動登録する。

## 提供する機能
- Launch Template(Amazon Linux 2023最新AMIをSSMパラメータ経由で取得、IMDSv2必須化、EBS暗号化、詳細モニタリング有効)
- Auto Scaling Group(プライベートサブネット・複数AZ、`min_size`/`max_size`/`desired_capacity` で台数制御)
- ターゲット追跡スケーリングポリシー(CPU使用率がしきい値を超えたらスケールアウト、下回れば自動でスケールイン)
- APIサーバ用セキュリティグループ(ALBのセキュリティグループからの80番のみ許可。SSH等インターネットからの直接アクセスは一切許可しない)
- SSM Session Manager用IAMロール(SSHポートを開けずに運用アクセスするための代替手段)

## 使用例

```hcl
module "asg_api" {
  source = "../../modules/asg-api"

  name                   = "myproject-dev"
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_security_group_id  = module.alb.security_group_id
  target_group_arn       = module.alb.target_group_arn

  instance_type    = "t2.micro"
  user_data        = file("${path.module}/templates/userdata.sh")
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  cpu_target_value = 70

  tags = local.common_tags
}
```

## セキュリティ上の注意点
- `user_data` には機密情報(パスワード・APIキー等)を含めないこと。ユーザデータはEC2メタデータ経由で参照可能であり、tfstateにも平文で残るため、認証情報が必要な場合はAWS Secrets Manager等からインスタンス起動後に取得する設計にすること([../../docs/05_development_guidelines.md](../../docs/05_development_guidelines.md)参照)。
- APIサーバはプライベートサブネットに配置し、SSHポート(22番)は一切開放していない。運用時のログインが必要な場合は、付与済みのIAMロール(`AmazonSSMManagedInstanceCore`)を利用してSSM Session Manager経由で接続すること。
- 本モジュール単体ではNAT Gatewayを提供しない。EC2からのアウトバウンド通信(ソフトウェアインストール等)には `modules/vpc-routing` で作成したNAT Gateway経由の経路が必要。

## Inputs / Outputs
`variables.tf` / `outputs.tf` を参照。全ての変数・出力に `description` を付与している。
