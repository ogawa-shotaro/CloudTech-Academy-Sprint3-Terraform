# modules/alb

おみくじAPI向けのApplication Load Balancer(ALB)モジュール。インターネットからのHTTP(80番)通信のみを受け付け、複数AZのAPIサーバへ負荷分散する。

## 提供する機能
- ALB(internet-facing、複数AZのパブリックサブネットに配置)
- ALB用セキュリティグループ(インターネットからの80番受信のみ許可)
- ターゲットグループ(HTTPヘルスチェック付き)
- HTTPリスナー(80番 → ターゲットグループへフォワード)
- 不正なHTTPヘッダを含むリクエストの拒否(`drop_invalid_header_fields = true`)

## 使用例

```hcl
module "alb" {
  source = "../../modules/alb"

  name              = "myproject-dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  target_port       = 80
  health_check_path = "/"

  tags = local.common_tags
}
```

## セキュリティ上の注意点
- 本モジュールは要件に基づきHTTP(80番)のみをサポートする。HTTPS化する場合はACM証明書の取得、443番リスナー追加、HTTP→HTTPSリダイレクト設定を別途行うこと。
- 以下の項目は `.checkov.yaml` で意図的にskipしている(理由はコメント参照): アクセスログ未設定、削除保護無効、WAF未接続、HTTPSリダイレクト無し。いずれも学習/dev環境でのスコープ外・コスト最適化のための判断であり、本番運用時は再検討すること。

## Inputs / Outputs
`variables.tf` / `outputs.tf` を参照。全ての変数・出力に `description` を付与している。
