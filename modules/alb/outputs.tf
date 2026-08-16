output "alb_arn" {
  description = "作成したALBのARN"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALBのDNS名(アクセス確認用)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALBのRoute53ホストゾーンID"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "APIサーバ用ターゲットグループのARN"
  value       = aws_lb_target_group.api.arn
}

output "security_group_id" {
  description = "ALBに付与したセキュリティグループのID"
  value       = aws_security_group.alb.id
}
