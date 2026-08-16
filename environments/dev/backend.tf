# ---------------------------------------------------------------------------
# デフォルトはローカルstateです。
#
# リモートstateを有効化する場合は以下のコメントを外し、事前に
#   - S3バケット(バージョニング有効、SSE暗号化、パブリックアクセスブロック有効)
#   - DynamoDBテーブル(ロック用。パーティションキー: LockID(String)、PAY_PER_REQUEST)
# を作成した上で値を設定してください。
#
# tfstateには機密情報を含めない設計にすること。リモート化してもこの前提は変わらない。
# ---------------------------------------------------------------------------
# terraform {
#   backend "s3" {
#     bucket         = "your-tfstate-bucket"
#     key            = "environments/dev/terraform.tfstate"
#     region         = "ap-northeast-1"
#     dynamodb_table = "your-tfstate-lock-table"
#     encrypt        = true
#   }
# }
