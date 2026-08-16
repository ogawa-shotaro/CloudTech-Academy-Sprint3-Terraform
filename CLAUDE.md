# CloudTech-Academy-Sprint3-Terraform: Terraformセキュア基盤ガイド

このリポジトリは [terraform-infra](../terraform-infra) を土台(スターターキット)として作成した、CloudTech Academy Sprint3向けのAWS Terraformプロジェクトです。土台リポジトリのルールをそのまま踏襲します。

## 必須ルール(絶対に守ること)

1. **Terraformの変更は必ずcheckovでチェックする**
   - コミット前に `make checkov` または `pre-commit run` を実行し、Critical/High相当の指摘がないことを確認する。
   - 誤検知等でスキップする場合は `.checkov.yaml` の `skip-check` に追加し、**理由を必ずコメントで残す**こと。理由のないskipは禁止。

2. **Docker関連ファイルを扱う場合は必ずTrivyでスキャンする**
   - Dockerfileのmisconfigurationは `make trivy-config`(`trivy config .`)
   - ビルドしたイメージの脆弱性は `make trivy-image IMAGE=<name:tag>`
   - 詳細は `docker/README.md` を参照。

3. **機密情報(パスワード・APIキー等)をTerraformで生成・管理しない**
   - `sensitive = true` を付けてもtfstateには平文で値が記録され、リモートbackend(S3等)にそのまま保存されるため安全ではない。
   - AWS Secrets Manager等の機密情報管理サービスに**事前または事後に別プロセス/手動で**投入し、Terraformは `data` ソースでARNや値を**参照するだけ**にするか、一切関与しない設計にする。
   - RDS等は可能な限り `manage_master_user_password = true`(RDS Managed Master Password)を使う。
   - 詳細は `modules/vpc/README.md` および `docs/05_development_guidelines.md` を参照。

4. **バージョンは固定しすぎず、常に最新に追従する**
   - `required_providers` / `required_version` は下限指定(`>= x.y`)を基本とし、上限固定はしない。
   - 定期的に `terraform init -upgrade` を実行し、providerを最新化する。

5. **作業前にdocs配下の関連ドキュメントを確認・更新する**
   - `docs/01_product_requirements.md`(プロダクト要求仕様書)
   - `docs/02_functional_design.md`(機能設計書)
   - `docs/03_technical_spec.md`(技術仕様書)
   - `docs/04_repository_structure.md`(リポジトリ構造仕様書)
   - `docs/05_development_guidelines.md`(開発ガイドライン)
   - 新機能追加時は `/add-feature` コマンドの手順に従うこと。

6. **コミット前に pre-commit を実行する**
   - 初回のみ `make pre-commit-install`
   - `terraform fmt` / `terraform validate` / `tflint` / `checkov` / `gitleaks` が自動実行される。

## モジュール設計規約

- 各モジュールは `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` / `README.md` を持つこと。
- 全ての `variable` / `output` に `description` を必須とする(tflintの `terraform_documented_variables` / `terraform_documented_outputs` で強制)。
- リソース名・変数名はsnake_case、モジュール名はkebab-caseを基本とする。
- セキュアデフォルト(暗号化有効化、パブリックアクセス禁止、ログ有効化等)を明示的に書く。省略時にセキュアになるオプションであっても、意図を明確にするため明示する。

## スラッシュコマンド

- `/add-feature` : 新しいモジュール/環境を追加する際のガイド付きワークフロー
- `/review` : checkov/tflint/terraform validate/(該当時)Trivyによる差分レビュー

## サブエージェント

- `terraform-security-reviewer` : checkov/tflintの検出結果の重要度判断と修正案提示に特化したサブエージェント
