# リポジトリ構造仕様書

```
.
├── README.md
├── .gitignore
├── .pre-commit-config.yaml
├── .checkov.yaml
├── .tflint.hcl
├── Makefile
├── docs/
│   ├── 01_product_requirements.md
│   ├── 02_functional_design.md
│   ├── 03_technical_spec.md
│   ├── 04_repository_structure.md
│   └── 05_development_guidelines.md
├── modules/
│   ├── vpc/
│   ├── vpc-routing/
│   ├── alb/
│   ├── asg-api/
│   └── README.md
├── environments/
│   └── dev/
│       └── templates/
│           └── userdata.sh
└── docker/
    └── README.md
```

## 各ディレクトリの役割

- `docs/` : プロジェクトドキュメント一式。新規プロジェクトを始める際は01〜02をコピーして記入し、03〜05は本リポジトリの内容をベースにプロジェクト固有の差分を追記する。
- `modules/` : 複数環境・複数プロジェクトで再利用するTerraformモジュール。1モジュール1ディレクトリとし、`main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` / `README.md` を必須とする。
- `environments/` : 環境ごと(dev/staging/prod等)のroot module。`modules/` を呼び出すのみとし、環境固有の値(CIDR、インスタンスサイズ等)のみを持つ。
- `docker/` : Dockerを利用する際の運用メモ。Dockerfileを追加する場合はTrivyでのスキャンを必須とする。

## 本プロジェクトでの次のステップ
1. `make check`(fmt/validate/tflint/checkov)を実行し、問題なければコミットする。
2. `terraform apply` 後、ALBのDNS名(`terraform output alb_dns_name`)経由でおみくじAPI(`/omikuji`, `/health`, `/hostname`, `/stress`)に疎通確認する。
3. `/stress` エンドポイントでCPU負荷をかけ、Auto Scaling(2→最大4台)が想定どおり動作するか確認する。
