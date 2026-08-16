output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "パブリックサブネットのID一覧"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "おみくじAPIへのアクセスに使用するALBのDNS名"
  value       = aws_lb.this.dns_name
}

output "asg_name" {
  description = "APIサーバAuto Scaling Groupの名前"
  value       = aws_autoscaling_group.api.name
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway(単一構成)のパブリックIP"
  value       = aws_eip.nat.public_ip
}
