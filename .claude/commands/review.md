---
description: Terraform変更に対してcheckov/tflint/Trivyによるセキュリティレビューを実行する
---

# /review

現在の変更(または指定されたパス)に対して、以下を順番に実行し結果をレビューしてください。

1. `terraform fmt -recursive -check`(差分があれば `terraform fmt -recursive` の実行を提案する)
2. 変更のある `environments/*` ディレクトリで `terraform init -backend=false -input=false && terraform validate`
3. `tflint --init && tflint --config=.tflint.hcl --recursive`
4. `checkov -d . --config-file .checkov.yaml`
5. Dockerfile/docker-compose等の変更があれば `trivy config .`(該当ファイルが無ければスキップ)

## レビュー観点
- checkov/tflintの指摘のうち **Critical/High** は原則修正案を提示する。skip-checkにする場合は理由を明記する。
- `terraform-security-reviewer` サブエージェントを使って、生の検出結果を要約・優先度付けしてもらうこと。
- 機密情報(パスワード等)がTerraformコード内で生成・平文管理されていないか(`random_password` の不適切な利用、`sensitive` 頼みの設計になっていないか)を確認する。
- バージョン制約が上限固定(`=` や過度な `~>`)になっていないか確認する。

## 出力
- 実行した各コマンドの結果概要(Pass/Fail、指摘件数)
- Critical/High指摘の一覧と修正提案
- その他の指摘の要約
- 総合判定(マージ可否の推奨)
