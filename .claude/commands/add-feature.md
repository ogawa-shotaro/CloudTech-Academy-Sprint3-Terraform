---
description: 新しいTerraformモジュール/環境を安全に追加するワークフロー
---

# /add-feature

新しいTerraformモジュールまたは環境を追加する際は、以下の手順を順番に実行してください。

1. **要求・設計ドキュメントの確認**
   - `docs/01_product_requirements.md` と `docs/02_functional_design.md` を確認し、今回追加する機能がドキュメントに反映されているか確認する。反映されていなければユーザーに追記を促す、または一緒に更新する。

2. **ヒアリング**
   - 何を作るか(リソース種別)、どの環境(`environments/*`)向けか、セキュリティ要件(暗号化・公開範囲・機密情報の有無)をユーザーに確認する。
   - 機密情報(パスワード等)を扱う場合は、Terraformで生成・管理せず、AWS Secrets Manager等の外部管理にする方針であることをユーザーと合意する(`CLAUDE.md` 必須ルール参照)。

3. **実装**
   - 再利用可能なリソースは `modules/<module-name>/` に追加する。`main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` / `README.md` を作成する。
   - 既存の `modules/vpc` を実装パターンの参考にする(セキュアデフォルト、description必須、下限バージョン指定)。
   - 環境固有の値は `environments/<env>/` 側の呼び出しに閉じ込める。

4. **セキュリティ・Lintチェック**
   - `make fmt && make validate && make tflint && make checkov` を実行する(または `/review` コマンドを使う)。
   - Dockerfileを追加した場合は `make trivy-config` も実行する。
   - Critical/High指摘が出た場合は修正する。skipする場合は理由コメント必須。

5. **ドキュメント更新**
   - `docs/03_technical_spec.md` / `docs/04_repository_structure.md` に新規モジュール・環境の情報を追記する。
   - 追加したモジュールの `README.md` に用途・入出力・セキュリティ上の注意点を記載する。

6. **最終確認**
   - チェック結果のサマリをユーザーに提示し、コミット前に承認を得る。
