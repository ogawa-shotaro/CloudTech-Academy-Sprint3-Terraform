variable "name" {
  description = "リソース名に付与するプレフィックス"
  type        = string
}

variable "vpc_id" {
  description = "対象VPCのID"
  type        = string
}

variable "public_subnet_ids" {
  description = "パブリックサブネットのID一覧(先頭のサブネットにNAT Gatewayを配置する)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  type        = list(string)
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
