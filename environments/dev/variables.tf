variable "project" {
  description = "プロジェクト名(タグ・リソース名prefixに使用)。ALB/ターゲットグループ名は32文字制限があるため、'{project}-{environment}'が25文字以内に収まる長さにすること"
  type        = string
  default     = "academy-sprint3"
}

variable "environment" {
  description = "環境名(dev/staging/prod等)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "デプロイ先のAWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "使用するアベイラビリティゾーン一覧"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロック一覧"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロック一覧"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "api_instance_type" {
  description = "おみくじAPIサーバのEC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
}

variable "api_health_check_path" {
  description = "ALBがAPIサーバのヘルスチェックに使用するパス"
  type        = string
  default     = "/health"
}

variable "asg_min_size" {
  description = "APIサーバAuto Scaling Groupの最小インスタンス数"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "APIサーバAuto Scaling Groupの最大インスタンス数"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "APIサーバAuto Scaling Groupの希望インスタンス数"
  type        = number
  default     = 2
}

variable "asg_cpu_target_value" {
  description = "Auto ScalingのCPU使用率しきい値(%)。超過でスケールアウトする"
  type        = number
  default     = 70
}
