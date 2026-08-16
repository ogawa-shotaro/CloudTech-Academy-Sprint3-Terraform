terraform {
  # バージョンは下限指定とし、定期的に `terraform init -upgrade` で最新化する。
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
