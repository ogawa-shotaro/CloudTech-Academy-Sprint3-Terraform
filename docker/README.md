# docker/

Dockerを利用するプロジェクト・モジュールを追加する場合の運用メモです。checkovはIaC(Terraform)向けのため、Dockerfile/コンテナイメージには **Trivy** を使用します。

## 使い方

### 1. Dockerfileのmisconfigurationチェック
```
make trivy-config
# 内部的には: trivy config .
```
Dockerfileの記述ミス(root実行、不要な公開ポート等)を検出します。

### 2. ビルド済みイメージの脆弱性スキャン
```
make trivy-image IMAGE=myapp:latest
# 内部的には: trivy image myapp:latest
```
OS/言語パッケージの既知脆弱性(CVE)を検出します。CI/ローカルどちらでもビルド直後に実行してください。

## ルール
- Dockerfileを追加/変更した場合、コミット前に必ず `make trivy-config` を実行する(pre-commitでもDockerfile変更時に自動実行される)。
- Critical/High脆弱性が検出された場合は、ベースイメージの更新やパッケージの更新で対応する。やむを得ず許容する場合は理由をコミットメッセージ/PRに明記する。
- ベースイメージのバージョンは(Terraform providerと同様に)固定しすぎず、定期的に最新化する。
