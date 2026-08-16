# 技術仕様書(CloudTech-Academy-Sprint3-Terraform)

## 1. 対象範囲
本ドキュメントは `CloudTech-Academy-Sprint3-Terraform` リポジトリの技術仕様を記載する。土台とした [terraform-infra](../../terraform-infra) の内容をベースに、本プロジェクト固有の差分をここに追記する。

## 2. 使用技術
| 項目 | 内容 |
|---|---|
| IaC | Terraform(`required_version >= 1.9`、下限指定・随時最新化) |
| クラウド | AWS |
| Provider | `hashicorp/aws`(`>= 5.0`、下限指定・随時最新化) |
| セキュリティ静的解析(IaC) | checkov |
| セキュリティ静的解析(コンテナ/Dockerfile) | Trivy |
| Lint | tflint(ruleset: aws) |
| Git hook管理 | pre-commit |
| Secret管理 | AWS Secrets Manager(Terraform管理外) |

## 3. ディレクトリ構成
`docs/04_repository_structure.md` を参照。

## 3-1. 本プロジェクト(おみくじAPI基盤)固有の構成
- 環境: `environments/dev` のみ(2AZ構成: `ap-northeast-1a` / `ap-northeast-1c`)。
- 使用モジュール: `modules/vpc`(既存) + `modules/vpc-routing` / `modules/alb` / `modules/asg-api`(本プロジェクトで新規追加)。詳細は `modules/README.md` を参照。
- ネットワーク: NAT GatewayはAZごとではなく**単一構成**(コスト優先)。`modules/vpc-routing/README.md` に単一障害点となる旨を明記済み。
- APIサーバ: Amazon Linux 2023 / `t2.micro`、Auto Scaling Group(2〜4台、CPU使用率70%でターゲット追跡スケーリング)。ユーザデータは `environments/dev/templates/userdata.sh`(Go製おみくじAPIをsystemdサービスとして80番ポートで起動。エンドポイント: `/omikuji` `/health` `/hostname` `/stress`)。ヘルスチェックは `/health` を使用する。
- アクセス制御: ALBは0.0.0.0/0:80のみ許可、APIサーバはALBのSGからの80番のみ許可(SSHは一切開放せず、運用アクセスはSSM Session Manager経由とする)。

## 4. State管理
- 初期状態はローカルstate。
- リモート化する場合は `environments/*/backend.tf` のコメントを解除し、事前にS3バケット(バージョニング・暗号化・パブリックアクセスブロック有効)とDynamoDBテーブル(ロック用)を用意する。
- **tfstateには機密情報を残さない設計とする**(下記5節)。

## 5. 機密情報の扱い
- Terraformでは `random_password` 等によるシークレットの生成・管理を行わない。
- RDS等のパスワードは `manage_master_user_password = true`(RDS Managed Master Password、AWS Secrets Manager連携)を優先する。
- 外部シークレットの参照がどうしても必要な場合は `data "aws_secretsmanager_secret_version"` 等でARN/値を参照するのみとする。値をリソースの平文引数として渡すと、`sensitive = true` を付けてもtfstateには平文で残ることを常に意識する。
- シークレットの投入・ローテーションはTerraformの外(AWS CLI/コンソール/別パイプライン)で行う。

## 6. バージョン管理方針
- `required_providers` / `required_version` は下限指定(`>= x.y`)とし、上限固定(`=`や過度な`~>`)はしない。
- 定期的に `terraform init -upgrade` を実行し、`.terraform.lock.hcl` を更新・コミットする。

## 7. セキュリティチェック
- IaC: `make checkov`(`checkov -d . --config-file .checkov.yaml`)を全PR前に実行必須。
- コンテナ/Dockerfile: `make trivy-config` / `make trivy-image IMAGE=...`。
- pre-commitで上記に加え `terraform fmt` / `tflint` / `gitleaks` を自動実行する。
