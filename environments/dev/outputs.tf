output "vpc_id" {
  description = "作成したVPCのID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "パブリックサブネットのID一覧"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "プライベートサブネットのID一覧"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "おみくじAPIへのアクセスに使用するALBのDNS名"
  value       = module.alb.alb_dns_name
}

output "asg_name" {
  description = "APIサーバAuto Scaling Groupの名前"
  value       = module.asg_api.autoscaling_group_name
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway(単一構成)のパブリックIP"
  value       = module.vpc_routing.nat_gateway_public_ip
}
