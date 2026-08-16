# 開発ガイドライン

## 1. コーディング規約
- リソース名・変数名: snake_case
- モジュールディレクトリ名: kebab-case
- 全ての `variable` / `output` に `description` を必須とする
- タグは共通タグ(`Project`, `Environment`, `ManagedBy`)を必ず付与する

## 2. セキュリティ運用(必須)
1. Terraformの変更は必ず `make checkov` を通す。Critical/Highの指摘は原則修正する。
2. skip-checkを使う場合は `.checkov.yaml` に理由コメントを添えて追加する。理由のないskipはレビューで却下する。
3. Dockerfile/イメージを扱う場合は `make trivy-config` / `make trivy-image` を実行する。
4. **機密情報(パスワード・トークン・APIキー等)はTerraformで生成・管理しない。**
   - 理由: `sensitive = true` を付与してもtfstateには平文で記録され、S3等のリモートbackendにそのまま保存されるため。
   - 対応: AWS Secrets Managerに事前 or 事後に(手動 or 別パイプラインで)投入し、Terraform側は参照のみ、または一切関与しない。RDS等は `manage_master_user_password = true` を優先する。
5. バージョンは固定しすぎず、常に最新に追従する。`required_providers` / `required_version` は下限指定とし、定期的に `terraform init -upgrade` を実行する。

## 3. 開発フロー
1. 作業前に `docs/` の関連ドキュメントを確認・更新する。
2. 新機能(モジュール/環境)追加は `/add-feature` コマンドの手順に従う。
3. 実装後、`/review` コマンド(または `make check`)でセキュリティ・Lintチェックを実行する。
4. `make pre-commit-install` を初回に実行し、以降はpre-commit経由でコミット時に自動チェックする。
5. PRには実行したチェック結果(checkov/tflint/trivy)を記載する。

## 4. レビュー観点
- セキュリティ: 暗号化、パブリック公開範囲、IAM最小権限、機密情報の扱い
- 設計: モジュールの再利用性、環境間の差分がvariablesのみに閉じているか
- 運用: タグ付け、ログ・監視の有無
