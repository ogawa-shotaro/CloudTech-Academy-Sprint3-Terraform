# modules/

複数の環境・プロジェクトで再利用するTerraformモジュールを配置するディレクトリです。

## モジュール追加時のルール

1. ディレクトリ名はkebab-case(例: `modules/rds-postgres/`)。
2. 以下のファイルを必須とする:
   - `main.tf`
   - `variables.tf`(全 `variable` に `description` 必須)
   - `outputs.tf`(全 `output` に `description` 必須)
   - `versions.tf`(`required_version` / `required_providers` は下限指定 `>= x.y` とする)
   - `README.md`(用途、入出力一覧、セキュリティ上の注意点)
3. セキュアデフォルト(暗号化・パブリックアクセス禁止・ログ有効化等)を明示的に書く。
4. 機密情報(パスワード等)を扱うモジュールは、Terraformで生成・平文管理しない。AWS Secrets Manager等の参照方式、またはRDSの `manage_master_user_password = true` を使う([../docs/05_development_guidelines.md](../docs/05_development_guidelines.md)参照)。
5. 追加後は `make checkov` / `make tflint` で確認する。

## 一覧

| モジュール | 用途 |
|---|---|
| `vpc` | セキュアデフォルトのVPC(フローログ・デフォルトSG制限付き) |
| `vpc-routing` | IGW・単一NAT Gateway・ルートテーブル(インターネット疎通) |
| `alb` | Application Load Balancer(HTTP:80のみ許可、複数AZ) |
| `asg-api` | おみくじAPIサーバのAuto Scaling Group(EC2/Amazon Linux 2023) |
