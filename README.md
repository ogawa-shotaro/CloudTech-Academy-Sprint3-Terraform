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
        ├── backend.tf.example  … リモートstate(S3)を有効化する際の参考テンプレート(現状未使用)
        ├── golden_ami_launch_template.tf.example … Golden AMI方式にする場合の参考例(現状未使用)
        ├── versions.tf         … Terraform/AWSプロバイダのバージョン制約
        └── templates/userdata.sh … おみくじAPI(Go)を起動するユーザデータスクリプト
```

ファイルはリソースの種類ごとに分割しています(Terraformは同一ディレクトリ内の`.tf`ファイルをすべて結合して読み込むため、ファイル名や分割方法はリソースの依存関係に影響しません)。

## 設計ポイント

- **モジュール化はせず、1つの環境に直接記述**: 現時点では`dev`環境1つしか無く、他プロジェクトでの再利用も予定していないため、モジュール分割による抽象化コストよりも「上から下に読めば全体が分かる」シンプルさを優先している。
- **セキュリティグループのルールは独立したリソース(`aws_vpc_security_group_ingress_rule`/`egress_rule`)で書く**: ALB用SGとAPIサーバ用SGは互いのSGを参照し合う関係にあるため、`aws_security_group`本体に`ingress`/`egress`を直接書く「インラインブロック方式」だと循環参照(ALBを作るにはAPIのIDが要り、APIを作るにはALBのIDが要る)になりTerraformが解決できない。ルールを別リソースにすることで、先に両方のSG(箱)を作ってから、後でお互いを参照するルールを追加でき、循環を避けられる。
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

## state管理(backend)について

Terraformは「今どのAWSリソースを管理しているか」を`terraform.tfstate`というファイルに記録します。この記録先(保存場所)の設定を「backend」と呼びます。

- **現状**: backend設定は無く、デフォルトの**ローカルstate**(自分のPC上に`terraform.tfstate`を保存)を使っています。個人の学習・検証用途であれば、これで問題ありません。`.gitignore`で除外しているため、このファイルはGitには含まれません。
- **チーム開発やCI/CDに移行する場合**: 複数人・複数環境から同じstateを扱う必要が出てくるため、以下の構成に変更することを想定しています(`environments/dev/backend.tf.example`に設定例を用意済み)。
  - **S3**: stateファイルをS3バケットに保存する。ローカルではなく共有ストレージに置くことで、誰がapplyしても同じstateを参照できるようにする。
  - **DynamoDBによるロック**: 2人が同時に`terraform apply`すると、stateが競合して壊れる可能性がある。applyの開始時にDynamoDBへ「今使用中」というロック情報を書き込み、他の人は解放されるまで待つことで、同時実行による破壊を防ぐ。
- 有効化するには、事前にS3バケット(バージョニング・暗号化・パブリックアクセスブロック有効)とDynamoDBテーブル(ロック用)を作成した上で、`backend.tf.example`の内容を`backend.tf`にコピーし、値を実際のバケット名等に書き換えて`terraform init`を再実行します。
- リモート化してもstateの中身自体が暗号化されて読めなくなるわけではないため、機密情報をtfstateに残さない設計(パスワード等はAWS Secrets Manager等で管理し、Terraformでは生成・平文管理しない)という前提は変わりません。

## コード中の見慣れない書き方について

コード内に付けているコメントには、次の2種類のタグを付けています。grepするとすぐ見つけられます。

- `[Terraform構文]`: **checkov等のツールとは無関係**な、Terraform言語そのものの機能。少し高度な書き方だが、AWS/セキュリティの話ではなく「同じことを繰り返し書かずに済ませるための構文」。
  - `count` / `count.index`: 同じ設定のリソースを指定した数だけ繰り返し作成する(例: AZの数だけサブネットを作る)
  - `[*]`(splat式): リストの各要素から特定の属性だけを取り出して配列にする
  - `dynamic` block: 決まった形のブロックを、mapやリストの要素数だけ自動生成する
  - `merge()`: 複数のmap(連想配列)を1つに結合する関数(共通タグに個別タグを追加する用途で多用)
  - `data`ブロック: 新しいリソースを作らず、既存の情報を読み取るための構文(例: 最新のAMI IDをSSM Parameter Storeから取得)
- `[セキュリティ]`: AWSのセキュリティベストプラクティスに沿って明示的に指定している設定。**checkovやtflintのようなツールを実際に使っていなくても書くべき内容**ですが、このプロジェクトの開発では実際にcheckov/tflintでのチェックを通す前提でコードを書いていたため、その基準を満たす書き方になっています。
  - デフォルトセキュリティグループを何もルール無しにして塞ぐ
  - `map_public_ip_on_launch = false`、EBS暗号化(`encrypted = true`)などの明示的な指定
  - IMDSv2の必須化(`http_tokens = "required"`)
  - セキュリティグループの許可先をIPアドレスではなく他のセキュリティグループIDで指定する(`aws_vpc_security_group_ingress_rule`/`egress_rule`では`referenced_security_group_id`という属性名になる。同様に`cidr_blocks`→`cidr_ipv4`、`protocol`→`ip_protocol`など、旧来のインラインブロックとは属性名が少し異なる点に注意)
  - 各セキュリティグループルールへの`description`付与

つまり、見慣れない書き方の多くは「checkov/tflintを入れたから追加された特殊な記法」ではなく、**Terraform自体の標準機能**か、**checkov/tflintが無くても本来書くべきセキュリティ設定を、ツール無しでも満たすように明示的に書いたもの**です。ツールの設定ファイル自体は前述のとおり今は未コミットですが、書き方の基準は変えていません。

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
