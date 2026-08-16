variable "name" {
  description = "リソース名に付与するプレフィックス"
  type        = string
}

variable "vpc_id" {
  description = "対象VPCのID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALBを配置するパブリックサブネットのID一覧(複数AZ推奨)"
  type        = list(string)
}

variable "target_port" {
  description = "ターゲットグループがEC2インスタンスへ転送する際のポート番号"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ヘルスチェックに使用するパス"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
