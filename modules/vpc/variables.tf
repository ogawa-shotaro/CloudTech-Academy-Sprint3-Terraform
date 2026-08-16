variable "name" {
  description = "リソース名に付与するプレフィックス"
  type        = string
}

variable "cidr_block" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "使用するアベイラビリティゾーン一覧"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロック一覧(azsと同じ順序で対応させる)"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロック一覧(azsと同じ順序で対応させる)"
  type        = list(string)
  default     = []
}

variable "flow_log_retention_in_days" {
  description = "VPCフローログを保存するCloudWatch Logsの保持日数"
  type        = number
  default     = 365
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
