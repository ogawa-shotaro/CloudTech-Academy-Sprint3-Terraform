variable "name" {
  description = "リソース名に付与するプレフィックス"
  type        = string
}

variable "vpc_id" {
  description = "対象VPCのID"
  type        = string
}

variable "private_subnet_ids" {
  description = "APIサーバ(EC2)を配置するプライベートサブネットのID一覧(複数AZ推奨)"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALBのセキュリティグループID(このSGからのアクセスのみAPIサーバへの通信を許可する)"
  type        = string
}

variable "target_group_arn" {
  description = "APIサーバを登録するALBターゲットグループのARN"
  type        = string
}

variable "ami_ssm_parameter_name" {
  description = "AMI取得に使用するSSMパラメータ名(デフォルトはAmazon Linux 2023の最新AMI)"
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "instance_type" {
  description = "EC2インスタンスタイプ"
  type        = string
  default     = "t2.micro"
}

variable "user_data" {
  description = "EC2起動時に実行するユーザデータスクリプト(rawテキスト。base64エンコードはモジュール内で行う)"
  type        = string
}

variable "min_size" {
  description = "Auto Scaling Groupの最小インスタンス数"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Auto Scaling Groupの最大インスタンス数"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Auto Scaling Groupの希望インスタンス数"
  type        = number
  default     = 2
}

variable "cpu_target_value" {
  description = "ターゲット追跡スケーリングのCPU使用率しきい値(%)。この値を超えるとスケールアウトする"
  type        = number
  default     = 70
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}
