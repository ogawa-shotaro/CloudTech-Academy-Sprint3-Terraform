output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "作成したVPCのCIDRブロック"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "パブリックサブネットのID一覧"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  value       = aws_subnet.private[*].id
}

output "flow_log_group_name" {
  description = "VPCフローログを保存するCloudWatch Logsロググループ名"
  value       = aws_cloudwatch_log_group.flow_log.name
}
