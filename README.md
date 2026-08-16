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
        │ outbound 80/443 (NAT経由)             │
        └───────────────┬───────────────────────┘
                    ┌────▼─────┐
                    │ NAT GW    │  単一構成(コスト優先)
                    └────┬─────┘
                    ┌────▼─────┐
                    │   IGW     │
                    └──────────┘
```

## ディレクトリ構成

```
.
├── environments/
│   └── dev/              … dev環境のroot module(モジュールを呼び出すのみ)
│       ├── main.tf        … provider・共通タグ・モジュール呼び出し
│       ├── variables.tf   … 環境固有値(リージョン/CIDR/AZ/インスタンスタイプ等)
│       ├── outputs.tf     … ALBのDNS名など動作確認用の出力
│       ├── backend.tf     … state管理設定(現状ローカル、S3化の手順をコメントで記載)
│       ├── versions.tf    … Terraform/AWSプロバイダのバージョン制約
│       └── templates/userdata.sh … おみくじAPI(Go)を起動するユーザデータスクリプト
└── modules/
    ├── vpc/          … VPC本体・パブリック/プライベートサブネット・VPCフローログ
    ├── vpc-routing/  … IGW・単一NAT Gateway・ルートテーブル(インターネット疎通)
    ├── alb/          … ALB・ターゲットグループ・HTTPリスナー(80番のみ許可)
    └── asg-api/      … APIサーバのLaunch Template・Auto Scaling Group・スケーリングポリシー
```

各モジュールは `main.tf`(主要リソース)を軸に、`security_group.tf` / `iam.tf` / `flow_logs.tf` / `nat_gateway.tf` / `launch_template.tf` など性質の異なるリソースを別ファイルに分割し、`variables.tf` / `outputs.tf` / `versions.tf` を備える構成にしています(Terraformは同一ディレクトリ内の`.tf`ファイルをすべて結合して読み込むため、ファイル分割はリソースの依存関係に影響しません)。

## environments/dev の設計ポイント

- **モジュール呼び出しのみで構成**: `vpc` → `vpc_routing` → `alb` → `asg_api` の4モジュールを呼び出す。環境固有の値(CIDR、インスタンスタイプ、ASGの台数等)は`variables.tf`にのみ持たせ、実装は`modules/`側に閉じている。
- **`asg_api` は `depends_on = [module.vpc_routing]` を明示**: EC2のユーザデータ(`dnf update`等)がインターネット到達性を必要とするため、NAT Gateway/ルーティングが先に用意されてからEC2を起動するよう順序を保証している。
- **共通タグ**: `local.common_tags`(`Project`/`Environment`/`ManagedBy`)を全モジュールに付与。
- **命名の長さ制約への配慮**: `project`変数の説明に、ALB/ターゲットグループ名のAWS上の32文字制限(`{project}-{environment}`が25文字以内)を明記している。
- **ヘルスチェック**: ALBのヘルスチェックパスはアプリの`/health`エンドポイントに合わせている。

## 要件との対応

| 要件 | 対応 |
|---|---|
| APIサーバ(EC2, Amazon Linux 2023, ユーザデータで初期構築) | `modules/asg-api`(Launch Template) |
| ELBによる負荷分散・複数AZ配置 | `modules/alb` + `environments/dev`(2AZ構成) |
| Auto Scaling(通常2台、CPU70%超で最大4台) | `modules/asg-api`(ASG + ターゲット追跡スケーリングポリシー) |
| アクセス制御(ALBは80番のみ受信、APIサーバはALBからの80番のみ受信、アウトバウンドは許可) | `modules/alb`・`modules/asg-api`のセキュリティグループ、`modules/vpc-routing`のNAT Gateway |
| コスト優先(t2.micro、NAT単一構成) | `variables.tf`のデフォルト値、`modules/vpc-routing`(NAT単一構成) |

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
