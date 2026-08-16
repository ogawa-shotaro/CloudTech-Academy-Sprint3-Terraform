output "autoscaling_group_name" {
  description = "作成したAuto Scaling Groupの名前"
  value       = aws_autoscaling_group.api.name
}

output "launch_template_id" {
  description = "作成したLaunch TemplateのID"
  value       = aws_launch_template.api.id
}

output "security_group_id" {
  description = "APIサーバに付与したセキュリティグループのID"
  value       = aws_security_group.api.id
}

output "iam_role_name" {
  description = "APIサーバに付与したIAMロール名(SSM Session Manager用)"
  value       = aws_iam_role.api.name
}
