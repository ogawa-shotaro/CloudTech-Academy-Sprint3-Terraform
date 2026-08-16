# CloudTech-Academy-Sprint3-Terraform

CloudTech Academy Sprint3向けのAWS Terraformプロジェクトです。[terraform-infra](../terraform-infra) をセキュア基盤(スターターキット)として構築しています。

## 特徴
- Terraformの変更は必ず[checkov](https://www.checkov.io/)でセキュリティチェックする
- Dockerを利用する場合は[Trivy](https://trivy.dev/)で脆弱性スキャンする
- 機密情報(パスワード等)はTerraformで生成・管理せず、AWS Secrets Manager等を利用する
- プロダクト要求仕様書・機能設計書・技術仕様書・リポジトリ構造仕様書・開発ガイドラインを`docs/`配下に整備

詳細なルールは [docs/05_development_guidelines.md](./docs/05_development_guidelines.md) を参照してください。

## クイックスタート

```sh
# 初回のみ: pre-commitフックをインストール
make pre-commit-install

# フォーマット・検証・Lint・セキュリティチェックを一括実行
make check

# 個別実行
make fmt        # terraform fmt
make validate   # terraform validate (environments/*)
make tflint     # tflint
make checkov    # checkov

# Dockerを使う場合
make trivy-config
make trivy-image IMAGE=<name:tag>
```

## 必要なツール(ローカルにインストールしておくもの)
- [Terraform](https://developer.hashicorp.com/terraform) (`>= 1.9`)
- [checkov](https://www.checkov.io/)
- [tflint](https://github.com/terraform-linters/tflint)
- [pre-commit](https://pre-commit.com/)
- [Trivy](https://trivy.dev/)(Dockerを利用する場合)

## ディレクトリ構成
`docs/04_repository_structure.md` を参照してください。

## 次のステップ
1. `docs/01_product_requirements.md` / `docs/02_functional_design.md` にSprint3の要求・設計を記入する。
2. `modules/README.md` の作法に従って必要なモジュール・環境を追加する。
3. `make check` でセキュリティチェックを通してからコミットする。
