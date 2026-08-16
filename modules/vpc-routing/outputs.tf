output "internet_gateway_id" {
  description = "作成したInternet GatewayのID"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "作成したNAT GatewayのID"
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gatewayに割り当てたEIPのパブリックIP"
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "パブリックサブネット用ルートテーブルのID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "プライベートサブネット用ルートテーブルのID"
  value       = aws_route_table.private.id
}
