# modules/vpc

セキュアデフォルトのAWS VPCモジュール。

## 提供する機能
- VPC本体(DNSサポート・DNSホスト名有効化)
- パブリック/プライベートサブネット(可変長)
- デフォルトセキュリティグループの全トラフィック拒否(ingress/egressルール無し)
- VPCフローログ(全トラフィック、CloudWatch Logsへ出力、KMS暗号化、キーローテーション有効)
- パブリックサブネットへの自動public IP付与を明示的に無効化

## 使用例

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name                 = "myproject-dev"
  cidr_block           = "10.0.0.0/16"
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  tags = {
    Project     = "myproject"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

## セキュリティ上の注意点
- 本モジュールはネットワーク層のみを扱い、**機密情報は一切扱わない**。
- 本モジュールを利用してRDS等のパスワードが必要なリソースを構築する場合、パスワードをTerraformで生成・平文管理しないこと。`manage_master_user_password = true`(RDS Managed Master Password)や、AWS Secrets Managerへの事前投入+`data "aws_secretsmanager_secret_version"` 参照方式を使う。理由: `sensitive = true` を付与してもtfstateには平文で値が残り、リモートbackend(S3等)にそのまま保存されるため。詳細は[../../docs/05_development_guidelines.md](../../docs/05_development_guidelines.md)を参照。
- NAT Gatewayは本モジュールに含めていない(コスト・要件に応じて別モジュール化する想定)。プライベートサブネットからの外向き通信が必要な場合は別途追加すること。

## Inputs / Outputs
`variables.tf` / `outputs.tf` を参照。全ての変数・出力に `description` を付与している。
