# CloudTech-Academy-Sprint3-Terraform

おみくじAPIを高可用性・スケーラブルに稼働させるためのAWSインフラをTerraformで構築するプロジェクトです。ALB(Elastic Load Balancing)による負荷分散と、Auto ScalingによるEC2インスタンスの自動増減を実現します。

## アーキテクチャ概要

```
                         Internet
                            │
                        (0.0.0.0/0:80)
                            │
                    ┌───────▼────────┐
                    │  ALB (public)   │  複数AZのpublic subnetに配置
                    └───────┬────────┘
                     80/HTTP │ (ALBのSGのみ許可)
        ┌───────────────────┼───────────────────┐
        │                   │                   │
 ┌──────▼──────┐     ┌──────▼──────┐     Auto Scaling: 通常2台
 │ EC2 (AZ-a)   │     │ EC2 (AZ-c)   │     CPU使用率70%超で最大4台
 │ Amazon Linux │     │ Amazon Linux │     private subnetに配置
 │ 2023 / t2.micro│   │ 2023 / t2.micro│   SG: ALBからの80番のみ許可
 └──────┬──────┘     └──────┬──────┘
        │ outbound (NAT経由)                    │
        └───────────────┬───────────────────────┘
                    ┌────▼─────┐
                    │ NAT GW    │  単一構成(コスト優先)
                    └────┬─────┘
                    ┌────▼─────┐
                    │   IGW     │
                    └──────────┘
```

## ディレクトリ構成

学習・レビュー目的のシンプルな構成として、モジュール分割はせず `environments/dev` に直接リソースを書いています。

```
.
└── environments/
    └── dev/
        ├── main.tf             … provider・共通タグ(local)の定義
        ├── network.tf          … VPC・サブネット・IGW・NAT Gateway・ルートテーブル
        ├── security_groups.tf … ALB用SG・APIサーバ用SG
        ├── alb.tf              … ALB・ターゲットグループ・HTTPリスナー
        ├── asg.tf              … Launch Template・Auto Scaling Group・スケーリングポリシー
        ├── variables.tf        … 環境固有値(リージョン/CIDR/AZ/インスタンスタイプ等)
        ├── outputs.tf          … ALBのDNS名など動作確認用の出力
        ├── backend.tf          … state管理設定(現状ローカル、S3化の手順をコメントで記載)
        ├── versions.tf         … Terraform/AWSプロバイダのバージョン制約
        └── templates/userdata.sh … おみくじAPI(Go)を起動するユーザデータスクリプト
```

ファイルはリソースの種類ごとに分割しています(Terraformは同一ディレクトリ内の`.tf`ファイルをすべて結合して読み込むため、ファイル名や分割方法はリソースの依存関係に影響しません)。

## 設計ポイント

- **モジュール化はせず、1つの環境に直接記述**: 現時点では`dev`環境1つしか無く、他プロジェクトでの再利用も予定していないため、モジュール分割による抽象化コストよりも「上から下に読めば全体が分かる」シンプルさを優先している。
- **セキュリティグループはシンプルな`ingress`/`egress`インラインブロック方式**: 1つの`aws_security_group`リソースの中にルールを直接書く、Terraformで最も基本的な書き方を採用している。
- **`asg`は`depends_on = [aws_nat_gateway.this]`を明示**: EC2のユーザデータ(`dnf update`等)がインターネット到達性を必要とするため、NAT Gatewayが先に用意されてからEC2を起動するよう順序を保証している。
- **共通タグ**: `local.common_tags`(`Project`/`Environment`/`ManagedBy`)を全リソースに付与。
- **命名の長さ制約への配慮**: `project`変数の説明に、ALB/ターゲットグループ名のAWS上の32文字制限(`{project}-{environment}`が25文字以内)を明記している。
- **ヘルスチェック**: ALBのヘルスチェックパスはアプリの`/health`エンドポイントに合わせている。
- **要件に無い付加機能は入れていない**: VPCフローログ(KMS暗号化込み)やSSM Session Manager用IAMロールなど、Sprint3の要件には明記されていない「本番運用向けの上乗せ機能」は実装せず、要件そのものを満たす最小限の構成にしている。そのため現状、稼働中のEC2インスタンスへ直接ログインする手段は用意していない(要件上も「インターネットからの直接アクセス不可」のみが求められており、運用アクセス手段は要求されていない)。

## 要件との対応

| 要件 | 対応 |
|---|---|
| APIサーバ(EC2, Amazon Linux 2023, ユーザデータで初期構築) | `asg.tf`(Launch Template) |
| ELBによる負荷分散・複数AZ配置 | `alb.tf` + `variables.tf`(2AZ構成) |
| Auto Scaling(通常2台、CPU70%超で最大4台) | `asg.tf`(ASG + ターゲット追跡スケーリングポリシー) |
| アクセス制御(ALBは80番のみ受信、APIサーバはALBからの80番のみ受信、アウトバウンドは許可) | `security_groups.tf`、`network.tf`のNAT Gateway |
| コスト優先(t2.micro、NAT単一構成) | `variables.tf`のデフォルト値、`network.tf`(NAT単一構成) |

## 開発時のセキュリティ・品質チェックについて

本プロジェクトの開発では、Terraformコードの変更時に以下のチェックを実施しています。

- **checkov**: IaC(Terraform)のセキュリティ静的解析(`checkov -d . --config-file .checkov.yaml`)
- **tflint**: 命名規則・variable/outputの`description`必須化などのLint
- **terraform fmt / terraform validate**: フォーマット・構文チェック

現時点では、これらの設定ファイル(`.checkov.yaml` / `.tflint.hcl` / `Makefile` / `.pre-commit-config.yaml`)や設計ドキュメント(`docs/`)、AIエージェント向け設定(`CLAUDE.md` / `.claude/`)は、メンター確認後にあらためて追加する予定のため本リポジトリには含めていません。

## 動作確認

```sh
cd environments/dev
terraform init
terraform apply

# ALBのDNS名を取得してアクセス確認
terraform output alb_dns_name
curl http://$(terraform output -raw alb_dns_name)/health
curl http://$(terraform output -raw alb_dns_name)/omikuji
```
